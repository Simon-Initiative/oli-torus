defmodule OliWeb.Delivery.Instructor.PreviewPageContext do
  @moduledoc """
  Builds the server-side assigns needed to render a basic page in instructor preview.

  This module intentionally avoids learner delivery setup. It does not create page visits,
  resource accesses, attempts, submissions, scoring records, or learner progress events.
  """

  require Logger

  alias Oli.Activities
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.{PreviousNextIndex, Sections, Settings}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Grading
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Rendering.Content.JumpNavigation
  alias Oli.Rendering.{Context, Page}
  alias Oli.Resources
  alias Oli.Resources.PageContent
  alias Oli.Utils.BibUtils

  alias OliWeb.Components.Delivery.ActivityBankSelectionCriteria,
    as: ActivityBankSelectionCriteriaComponent

  alias OliWeb.ManualGrading.Rendering
  alias Oli.Rendering.Content.ActivityBankSelectionPreview

  def build(section, revision, user, navigation_params \\ %{}) do
    section_slug = section.slug

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, revision.resource_id)

    preview_data = build_preview_data(section, revision, user, navigation_params)

    activity_map = preview_data.activity_map
    summaries = preview_data.summaries
    page_summary = preview_data.page_summary
    html = preview_data.html

    bib_entries =
      revision.content
      |> BibUtils.assemble_bib_entries(
        summaries,
        fn summary -> Map.get(summary, :bib_refs, []) end,
        section_slug,
        Resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {summary, ordinal} -> BibUtils.serialize_revision(summary, ordinal) end)

    effective_settings =
      case user do
        nil -> Settings.get_combined_settings(revision, section.id)
        user -> Settings.get_combined_settings(revision, section.id, user.id)
      end

    section_resource = SectionResourceDepot.get_section_resource(section.id, revision.resource_id)
    numbered_revisions = Sections.get_revision_indexes(section.slug)

    objectives = preview_objectives(revision, section_slug)

    %{
      user: user,
      summary: %{title: section.title},
      section_slug: section_slug,
      scripts:
        summaries
        |> Enum.map(&preview_script_for_summary/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.concat(preview_data.activity_bank_selection_scripts)
        |> Enum.uniq(),
      preview_mode: true,
      previous_page: previous,
      next_page: next,
      numbered_revisions: numbered_revisions,
      current_page: current,
      current_page_resource_id: revision.resource_id,
      page_number: section_resource.numbering_index,
      question_count: map_size(activity_map),
      jump_targets: preview_data.jump_targets,
      title: revision.title,
      graded: revision.graded,
      review_mode: false,
      # Keep aggregate page-level state separate from the preview HTML so future work can update
      # totals like enabled points / objective coverage without rebuilding the page body.
      page_summary: page_summary,
      # Cache the immutable page/activity metadata needed to recompute page-level aggregates after
      # a remove/restore action. The page body itself remains a client-owned raw HTML island.
      preview_metadata: preview_data.preview_metadata,
      page_context: %{
        page: %{
          graded: revision.graded,
          title: revision.title,
          duration_minutes: revision.duration_minutes
        },
        effective_settings: effective_settings
      },
      previous_url:
        OliWeb.Delivery.Instructor.PreviewRoutes.resource_path(
          section_slug,
          previous,
          navigation_params
        ),
      next_url:
        OliWeb.Delivery.Instructor.PreviewRoutes.resource_path(
          section_slug,
          next,
          navigation_params
        ),
      navigation_params: navigation_params,
      html: html,
      objectives: objectives,
      page_link_url:
        &OliWeb.Delivery.Instructor.PreviewRoutes.lesson_path(
          section_slug,
          &1,
          navigation_params
        ),
      container_link_url:
        &OliWeb.Delivery.Instructor.PreviewRoutes.container_path(
          section_slug,
          &1,
          navigation_params
        ),
      section_title: section.title,
      resource_slug: revision.slug,
      display_curriculum_item_numbering: section.display_curriculum_item_numbering,
      hierarchy: thin_hierarchy(section),
      bib_app_params: %{
        bibReferences: bib_entries
      },
      collab_space_config: effective_settings.collab_space_config,
      notes_enabled?: notes_enabled?(effective_settings.collab_space_config),
      is_instructor: true,
      is_student: false,
      has_scheduled_resources?: SectionResourceDepot.has_scheduled_resources?(section.id)
    }
  end

  def build_page_summary(preview_metadata, exclusion_view) do
    # This summary is intentionally data-only. It lets header-level aggregates change
    # independently from the client-owned preview body as customization features expand.
    build_page_summary(
      preview_metadata.activity_ids,
      preview_metadata.activity_points_by_id,
      exclusion_view,
      preview_metadata.objective_titles_by_activity_id
    )
  end

  @doc """
  Builds preview HTML for a single bank candidate inside the bank-selection
  manager LiveView.

  This keeps the manager on the same instructor-preview rendering contract used
  by page preview, while letting the manager decide separately whether the
  candidate should expose customization actions or removed styling. Callers are
  expected to pass the current `can_customize?` / `actions` state for the
  selected candidate so the right-side manager preview stays aligned with the
  list's removed/restored state.
  """
  @spec build_bank_candidate_preview(
          %Sections.Section{},
          %Resources.Revision{},
          %Resources.Revision{},
          keyword()
        ) :: {:ok, %{html: String.t()}} | {:error, term()}
  def build_bank_candidate_preview(section, page_revision, activity_revision, opts \\ [])

  def build_bank_candidate_preview(
        %Sections.Section{} = section,
        %Resources.Revision{} = page_revision,
        %Resources.Revision{} = activity_revision,
        opts
      ) do
    all_activities = Activities.list_activity_registrations()
    activity_types_map = Map.new(all_activities, fn activity -> {activity.id, activity} end)

    with {:ok, activity_type} <- Map.fetch(activity_types_map, activity_revision.activity_type_id) do
      learning_objectives =
        preview_objective_titles_by_activity_id(section.id, [activity_revision])
        |> Map.get(activity_revision.resource_id, [])

      summary =
        %ActivitySummary{
          id: activity_revision.resource_id,
          script: preview_script_for(activity_type),
          attempt_guid: nil,
          state: nil,
          lifecycle_state: :active,
          model:
            activity_revision.content
            |> Jason.encode!()
            |> Oli.Delivery.Page.ActivityContext.encode(),
          delivery_element: activity_type.delivery_element,
          authoring_element: activity_type.authoring_element,
          preview_element: activity_type.preview_element,
          preview_script: activity_type.preview_script,
          graded: page_revision.graded,
          activity_type_slug: activity_type.slug,
          preview_context:
            build_preview_context(
              section.slug,
              page_revision,
              activity_revision,
              activity_type,
              learning_objectives,
              can_customize?: Keyword.get(opts, :can_customize?, false),
              actions: Keyword.get(opts, :actions, []),
              visual_state: Keyword.get(opts, :visual_state, "default"),
              status_pill: Keyword.get(opts, :status_pill),
              customization_target: %{
                kind: "bank_candidate",
                pageResourceId: page_revision.resource_id,
                selectionId: Keyword.get(opts, :selection_id),
                activityResourceId: activity_revision.resource_id
              }
            ),
          bib_refs: Map.get(activity_revision.content, "bibrefs", [])
        }

      context = %Context{
        section_slug: section.slug,
        revision_slug: page_revision.slug,
        page_id: page_revision.resource_id,
        mode: :instructor_preview,
        activity_map: %{activity_revision.resource_id => summary},
        activity_types_map: activity_types_map,
        bib_app_params: [],
        submitted_surveys: %{}
      }

      {:ok,
       %{
         html:
           context
           |> Rendering.render(:instructor_preview)
           |> IO.iodata_to_binary()
       }}
    end
  end

  @doc """
  Resolves the preview-side script filename for one activity registration.

  Manager-style LiveViews can use this to preload every script needed by the
  currently visible bank candidates, so switching the selected preview does not
  depend on script tags added later by a LiveView patch.
  """
  @spec preview_script_for_registration(map()) :: String.t() | nil
  def preview_script_for_registration(activity_type), do: preview_script_for(activity_type)

  defp activity_ids(content) do
    content
    |> PageContent.flat_filter(fn item -> item["type"] == "activity-reference" end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
  end

  defp jump_targets(content) do
    content
    |> PageContent.flat_filter(fn
      %{"type" => "activity-reference"} -> true
      %{"type" => "selection"} -> true
      _ -> false
    end)
    |> Enum.reduce({[], 0, 0}, fn
      %{"type" => "selection", "id" => id}, {items, selection_count, question_count} ->
        selection_count = selection_count + 1

        item = %{
          kind: :selection,
          label: "Selection #{selection_count}",
          target_id: JumpNavigation.selection_target_id(id)
        }

        {[item | items], selection_count, question_count}

      %{"type" => "activity-reference", "activity_id" => id} = element,
      {items, selection_count, question_count} ->
        question_count = question_count + 1

        item = %{
          kind: :question,
          label: "Question #{question_count}",
          target_id: Map.get(element, "jump_target_id", JumpNavigation.activity_target_id(id))
        }

        {[item | items], selection_count, question_count}

      _other, acc ->
        acc
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp add_jump_target_ids(content) do
    content
    |> PageContent.map_reduce(0, fn
      %{"type" => "activity-reference", "activity_id" => activity_id} = element,
      question_count,
      _tr_context ->
        question_count = question_count + 1
        target_id = JumpNavigation.activity_target_id(activity_id, question_count)

        {Map.put(element, "jump_target_id", target_id), question_count}

      element, question_count, _tr_context ->
        {element, question_count}
    end)
    |> elem(0)
  end

  defp preview_objectives(revision, section_slug) do
    attached_objective_ids =
      case revision.objectives["attached"] do
        list when is_list(list) -> list
        _ -> []
      end

    attached_objective_ids
    |> rollup_objective_revisions(section_slug)
    |> Enum.map(fn objective_revision ->
      %{
        resource_id: objective_revision.resource_id,
        title: objective_revision.title,
        proficiency: "Not enough data"
      }
    end)
  end

  defp rollup_objective_revisions([], _section_slug), do: []

  defp rollup_objective_revisions(attached_objective_ids, section_slug) do
    all = Resolver.from_resource_id(section_slug, attached_objective_ids)

    parents = Resolver.find_parent_objectives(section_slug, attached_objective_ids)

    referenced_children =
      Enum.reduce(parents, MapSet.new(), fn %{children: children}, acc ->
        Enum.reduce(children, acc, fn id, child_acc -> MapSet.put(child_acc, id) end)
      end)

    all
    |> Enum.reduce(parents, fn revision, revisions ->
      if MapSet.member?(referenced_children, revision.resource_id) do
        revisions
      else
        [revision | revisions]
      end
    end)
    |> Enum.uniq_by(& &1.resource_id)
    |> Enum.sort_by(& &1.title)
  end

  defp preview_supported?(%{slug: slug}),
    do: Activities.preview_supported_activity_slug?(slug)

  defp build_preview_data(section, revision, user, navigation_params) do
    section_slug = section.slug
    all_activities = Activities.list_activity_registrations()
    type_by_id = Map.new(all_activities, fn activity -> {activity.id, activity} end)
    content = add_jump_target_ids(revision.content)

    activity_revisions =
      content
      |> activity_ids()
      |> then(&Resolver.from_resource_id(section_slug, &1))

    objective_titles_by_activity_id =
      preview_objective_titles_by_activity_id(section.id, activity_revisions)

    exclusion_view =
      InstructorCustomizations.get_page_exclusion_view(section.id, revision.resource_id)

    activity_map =
      activity_revisions
      |> Enum.map(fn activity_revision ->
        type = Map.fetch!(type_by_id, activity_revision.activity_type_id)

        summary =
          activity_summary(
            section_slug,
            revision,
            activity_revision,
            type,
            exclusion_view,
            Map.get(objective_titles_by_activity_id, activity_revision.resource_id, [])
          )

        {summary.id, summary}
      end)
      |> Map.new()

    summaries = Map.values(activity_map)

    bib_entries =
      content
      |> BibUtils.assemble_bib_entries(
        summaries,
        fn summary -> Map.get(summary, :bib_refs, []) end,
        section_slug,
        Resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {summary, ordinal} -> BibUtils.serialize_revision(summary, ordinal) end)

    {activity_bank_selection_previews, activity_bank_selection_scripts} =
      ActivityBankSelectionPreview.build_preview_map(
        section,
        revision,
        all_activities,
        navigation_params
      )

    activity_bank_selection_previews =
      Map.new(activity_bank_selection_previews, fn {selection_id, preview} ->
        criteria_presentation = Map.get(preview, :criteria, %{})

        selection_criteria_html =
          ActivityBankSelectionCriteriaComponent.selection_criteria_html(
            Map.get(criteria_presentation, :rows, []),
            heading_id: "#{selection_id}-criteria-heading",
            helper_text: Map.get(criteria_presentation, :helper_text)
          )

        cleaned_preview =
          preview
          |> Map.delete(:criteria)
          |> Map.put(:selectionCriteriaHtml, selection_criteria_html)

        {selection_id, cleaned_preview}
      end)

    render_context =
      build_render_context(
        section,
        revision,
        user,
        activity_map,
        bib_entries,
        all_activities,
        activity_bank_selection_previews
      )

    html = Page.render(render_context, content, Page.Html)

    %{
      activity_map: activity_map,
      summaries: summaries,
      html: html,
      jump_targets: jump_targets(content),
      activity_bank_selection_scripts: activity_bank_selection_scripts,
      # Metadata cached on the LiveView so remove/restore can recompute aggregate page data
      # without repeating DB lookups for page activities and their objective labels.
      preview_metadata: %{
        activity_ids: Enum.map(activity_revisions, & &1.resource_id),
        activity_points_by_id:
          Map.new(activity_revisions, fn activity_revision ->
            {activity_revision.resource_id, Grading.determine_activity_out_of(activity_revision)}
          end),
        objective_titles_by_activity_id: objective_titles_by_activity_id,
        bank_selection_ids: Map.keys(activity_bank_selection_previews),
        bank_selection_available_counts_by_id:
          Map.new(activity_bank_selection_previews, fn {selection_id, preview} ->
            {selection_id, Map.get(preview, :originalAvailableCount, preview.availableCount)}
          end)
      },
      page_summary:
        build_page_summary(
          Enum.map(activity_revisions, & &1.resource_id),
          Map.new(activity_revisions, fn activity_revision ->
            {activity_revision.resource_id, Grading.determine_activity_out_of(activity_revision)}
          end),
          exclusion_view,
          objective_titles_by_activity_id
        )
    }
  end

  defp build_render_context(
         section,
         revision,
         user,
         activity_map,
         bib_entries,
         all_activities,
         activity_bank_selection_previews
       ) do
    section_slug = section.slug
    base_project_attributes = Sections.get_section_attributes(section)

    %Context{
      user: user,
      section_id: section.id,
      section_slug: section_slug,
      page_id: revision.resource_id,
      revision_slug: revision.slug,
      mode: :instructor_preview,
      activity_map: activity_map,
      instructor_preview_context: %{
        activity_bank_selections: activity_bank_selection_previews
      },
      resource_summary_fn: &Resources.resource_summary(&1, section_slug, Resolver),
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      activity_types_map: Map.new(all_activities, fn activity -> {activity.id, activity} end),
      bib_app_params: bib_entries,
      learning_language: base_project_attributes.learning_language,
      submitted_surveys: %{}
    }
  end

  defp activity_summary(
         section_slug,
         page_revision,
         activity_revision,
         type,
         exclusion_view,
         learning_objectives
       ) do
    %ActivitySummary{
      id: activity_revision.resource_id,
      script: preview_script_for(type),
      attempt_guid: nil,
      state: nil,
      lifecycle_state: :active,
      model:
        activity_revision.content
        |> Jason.encode!()
        |> Oli.Delivery.Page.ActivityContext.encode(),
      delivery_element: type.delivery_element,
      authoring_element: type.authoring_element,
      preview_element: type.preview_element,
      preview_script: type.preview_script,
      graded: page_revision.graded,
      activity_type_slug: type.slug,
      preview_context:
        build_preview_context(
          section_slug,
          page_revision,
          activity_revision,
          type,
          learning_objectives,
          can_customize?: preview_supported?(type),
          actions: preview_actions(exclusion_view, activity_revision.resource_id),
          visual_state:
            if(
              InstructorCustomizations.activity_enabled?(
                exclusion_view,
                activity_revision.resource_id
              ),
              do: "default",
              else: "removed"
            ),
          status_pill:
            if(
              InstructorCustomizations.activity_enabled?(
                exclusion_view,
                activity_revision.resource_id
              ),
              do: nil,
              else: %{kind: "removed", label: "Removed"}
            ),
          customization_target: %{
            kind: "embedded_activity",
            pageResourceId: page_revision.resource_id,
            activityResourceId: activity_revision.resource_id
          }
        ),
      bib_refs: Map.get(activity_revision.content, "bibrefs", [])
    }
  end

  defp build_page_summary(
         activity_ids,
         activity_points_by_id,
         exclusion_view,
         objective_titles_by_activity_id
       ) do
    enabled_activity_ids =
      Enum.filter(activity_ids, fn activity_id ->
        InstructorCustomizations.activity_enabled?(exclusion_view, activity_id)
      end)

    learning_objectives =
      enabled_activity_ids
      |> Enum.flat_map(fn activity_id ->
        Map.get(objective_titles_by_activity_id, activity_id, [])
      end)
      |> Enum.uniq()
      |> Enum.sort()

    %{
      enabled_activity_count: length(enabled_activity_ids),
      available_points:
        Enum.reduce(enabled_activity_ids, 0, fn activity_id, acc ->
          acc + Map.get(activity_points_by_id, activity_id, 0)
        end),
      learning_objectives: learning_objectives,
      learning_objective_count: length(learning_objectives)
    }
  end

  defp preview_actions(exclusion_view, activity_resource_id) do
    if InstructorCustomizations.activity_enabled?(exclusion_view, activity_resource_id) do
      [%{kind: "remove", label: "Remove"}]
    else
      [%{kind: "restore", label: "Restore"}]
    end
  end

  defp preview_script_for(%{
         slug: slug,
         preview_element: preview_element,
         preview_script: preview_script,
         authoring_script: authoring_script
       }) do
    if not is_nil(preview_element) and is_nil(preview_script) and
         Activities.preview_supported_activity_slug?(slug) do
      Logger.warning(
        "Instructor preview falling back to authoring script for supported activity type #{slug}"
      )
    end

    if preview_element, do: preview_script || authoring_script, else: authoring_script
  end

  defp preview_script_for_summary(%ActivitySummary{
         preview_element: preview_element,
         preview_script: preview_script,
         script: script
       }) do
    if preview_element, do: preview_script || script, else: script
  end

  defp build_preview_context(
         section_slug,
         page_revision,
         activity_revision,
         activity_type,
         learning_objectives,
         opts
       ) do
    %{
      sectionSlug: section_slug,
      pageResourceId: page_revision.resource_id,
      pageRevisionSlug: page_revision.slug,
      activityResourceId: activity_revision.resource_id,
      activityHtmlId:
        Map.get(activity_revision.content, "id", "activity_#{activity_revision.resource_id}"),
      activityTypeSlug: activity_type.slug,
      activityTypeLabel: activity_type.title,
      title: activity_revision.title,
      points: Grading.determine_activity_out_of(activity_revision),
      learningObjectives: learning_objectives,
      canCustomize: Keyword.get(opts, :can_customize?, false),
      actions: Keyword.get(opts, :actions, []),
      # Visual removed treatment is context-specific. Preview page cards use it so excluded
      # embedded activities are obvious in-place, while other surfaces can omit it and still
      # reuse the same Remove/Restore action contract.
      visualState: Keyword.get(opts, :visual_state, "default"),
      statusPill: Keyword.get(opts, :status_pill),
      customizationTarget: Keyword.get(opts, :customization_target)
    }
  end

  defp preview_objective_titles_by_activity_id(section_id, activity_revisions) do
    objective_titles_by_id =
      activity_revisions
      |> Enum.flat_map(&activity_objective_ids/1)
      |> Enum.uniq()
      |> case do
        [] ->
          %{}

        objective_ids ->
          SectionResourceDepot.objectives(section_id, [{:resource_id, {:in, objective_ids}}])
          |> Map.new(fn objective -> {objective.resource_id, objective.title} end)
      end

    Enum.reduce(activity_revisions, %{}, fn activity_revision, acc ->
      learning_objectives =
        activity_objective_ids(activity_revision)
        |> Enum.map(&Map.get(objective_titles_by_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      Map.put(acc, activity_revision.resource_id, learning_objectives)
    end)
  end

  defp activity_objective_ids(%{objectives: objectives}) when is_map(objectives) do
    objectives
    |> Map.values()
    |> Enum.flat_map(fn
      ids when is_list(ids) -> ids
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp activity_objective_ids(_), do: []

  defp thin_hierarchy(section) do
    section
    |> SectionResourceDepot.get_full_hierarchy(hidden: false)
    |> Hierarchy.thin_hierarchy(
      [
        "id",
        "slug",
        "title",
        "numbering",
        "resource_id",
        "resource_type_id",
        "children",
        "graded",
        "section_resource"
      ],
      fn node -> node["numbering"]["level"] <= 3 end
    )
  end

  defp notes_enabled?(%CollabSpaceConfig{status: :disabled}), do: false
  defp notes_enabled?(%CollabSpaceConfig{}), do: true
  defp notes_enabled?(_), do: false
end
