defmodule OliWeb.Delivery.Instructor.PreviewPageContext do
  @moduledoc """
  Builds the server-side assigns needed to render a basic page in instructor preview.

  This module intentionally avoids learner delivery setup. It does not create page visits,
  resource accesses, attempts, submissions, scoring records, or learner progress events.
  """

  require Logger

  alias Oli.Activities
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.{PreviousNextIndex, Sections, Settings}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Grading
  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Rendering.{Context, Page}
  alias Oli.Resources
  alias Oli.Utils.BibUtils

  def build(section, revision, user, navigation_params \\ %{}) do
    section_slug = section.slug

    {:ok, {previous, next, current}, _} =
      PreviousNextIndex.retrieve(section, revision.resource_id)

    all_activities = Activities.list_activity_registrations()
    type_by_id = Map.new(all_activities, fn activity -> {activity.id, activity} end)

    activity_revisions =
      revision.content
      |> activity_ids()
      |> then(&Resolver.from_resource_id(section_slug, &1))

    objective_titles_by_activity_id =
      preview_objective_titles_by_activity_id(section.id, activity_revisions)

    activity_map =
      activity_revisions
      |> Enum.map(fn activity_revision ->
        type = Map.fetch!(type_by_id, activity_revision.activity_type_id)

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
          graded: revision.graded,
          activity_type_slug: type.slug,
          preview_context:
            build_preview_context(
              section_slug,
              revision,
              activity_revision,
              type,
              preview_supported?(type),
              Map.get(objective_titles_by_activity_id, activity_revision.resource_id, [])
            ),
          bib_refs: Map.get(activity_revision.content, "bibrefs", [])
        }
      end)
      |> Map.new(fn summary -> {summary.id, summary} end)

    summaries = Map.values(activity_map)

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

    base_project_attributes = Sections.get_section_attributes(section)

    render_context = %Context{
      user: user,
      section_slug: section_slug,
      revision_slug: revision.slug,
      mode: :instructor_preview,
      activity_map: activity_map,
      resource_summary_fn: &Resources.resource_summary(&1, section_slug, Resolver),
      alternatives_selector_fn: &Resources.Alternatives.select/2,
      extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
      activity_types_map: Map.new(all_activities, fn activity -> {activity.id, activity} end),
      bib_app_params: bib_entries,
      learning_language: base_project_attributes.learning_language,
      submitted_surveys: %{}
    }

    html = Page.render(render_context, revision.content, Page.Html)

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
        |> Enum.uniq(),
      preview_mode: true,
      previous_page: previous,
      next_page: next,
      numbered_revisions: numbered_revisions,
      current_page: current,
      page_number: section_resource.numbering_index,
      question_count: map_size(activity_map),
      title: revision.title,
      graded: revision.graded,
      review_mode: false,
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

  defp activity_ids(content) do
    content
    |> Oli.Resources.PageContent.flat_filter(fn item -> item["type"] == "activity-reference" end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
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
         can_customize?,
         learning_objectives
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
      canCustomize: can_customize?,
      customizationTarget: %{
        kind: "embedded_activity",
        pageResourceId: page_revision.resource_id,
        activityResourceId: activity_revision.resource_id
      }
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
