defmodule Oli.Rendering.Content.ActivityBankSelectionPreview do
  @moduledoc false

  alias Oli.Activities.Realizer.Selection
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Grading
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Content.ActivityBankSelectionCriteria
  alias Oli.Rendering.Content.JumpNavigation
  alias Oli.Rendering.Context
  alias Oli.Resources.PageContent

  @script "instructor_preview_components.js"
  @element "oli-activity-bank-selection-preview"

  def script, do: @script

  def build_preview_map(section, page_revision, activity_types, navigation_params \\ %{}) do
    selections =
      PageContent.flat_filter(page_revision.content, fn
        %{"type" => "selection", "id" => id} when is_binary(id) -> true
        _ -> false
      end)

    selection_data =
      Enum.map(selections, fn selection ->
        {selection, parse_selection(selection)}
      end)

    activity_type_by_id =
      Map.new(activity_types, fn activity_type -> {activity_type.id, activity_type} end)

    activity_type_titles_by_id =
      Map.new(activity_types, fn activity_type -> {activity_type.id, activity_type.title} end)

    criteria_resource_titles_by_id =
      ActivityBankSelectionCriteria.resource_titles(section.slug, selection_data)

    previews =
      selection_data
      |> Enum.map(fn {selection, parsed_selection} ->
        {selection["id"],
         build_preview(
           section,
           page_revision,
           selection,
           parsed_selection,
           activity_type_by_id,
           activity_type_titles_by_id,
           criteria_resource_titles_by_id,
           navigation_params
         )}
      end)
      |> Map.new()

    scripts =
      if map_size(previews) == 0 do
        []
      else
        previews
        |> Map.values()
        |> Enum.flat_map(fn
          %{sampleActivity: %{script: script}} when is_binary(script) -> [script]
          _ -> []
        end)
        |> Enum.concat([@script])
        |> Enum.uniq()
      end

    {previews, scripts}
  end

  defp build_preview(
         section,
         page_revision,
         selection,
         parsed_selection,
         activity_type_by_id,
         activity_type_titles_by_id,
         criteria_resource_titles_by_id,
         navigation_params
       ) do
    selection_id = selection["id"]

    selection_summary =
      InstructorCustomizations.get_bank_selection_summary(
        section,
        page_revision.resource_id,
        selection_id
      )

    {selection_enabled?, available_count, original_available_count, sample_activity} =
      case selection_summary do
        {:ok,
         %{selection_enabled?: enabled?, active_count: active_count, sample_candidate: candidate}} ->
          effective_available_count = if enabled?, do: active_count, else: 0

          sample_activity =
            build_sample_activity(
              candidate,
              section,
              page_revision,
              selection_id,
              activity_type_by_id
            )

          {enabled?, effective_available_count, active_count, sample_activity}

        _ ->
          {true, 0, 0, nil}
      end

    points_per_activity = points_per_activity(parsed_selection, selection)
    select_count = select_count(parsed_selection, selection)

    criteria_presentation =
      ActivityBankSelectionCriteria.presentation(
        parsed_selection,
        activity_type_titles_by_id,
        criteria_resource_titles_by_id
      )

    %{
      id: selection_id,
      title: "Activity Bank Selection",
      pageResourceId: page_revision.resource_id,
      pageRevisionSlug: page_revision.slug,
      sectionSlug: section.slug,
      selectedCount: select_count,
      availableCount: available_count,
      originalAvailableCount: original_available_count,
      pointsPerActivity: points_per_activity,
      criteria: criteria_presentation,
      manageQuestionsUrl:
        manage_questions_url(section.slug, page_revision.slug, selection_id, navigation_params),
      sampleActivity: sample_activity,
      canCustomize: true,
      actions: actions(selection_enabled?),
      visualState: if(selection_enabled?, do: "default", else: "removed"),
      statusPill: if(selection_enabled?, do: nil, else: %{kind: "removed", label: "Removed"}),
      customizationTarget: %{
        kind: "bank_selection",
        pageResourceId: page_revision.resource_id,
        selectionId: selection_id
      }
    }
  end

  def render(
        %Context{instructor_preview_context: instructor_preview_context} = context,
        %{"id" => selection_id} = selection
      ) do
    previews = Map.get(instructor_preview_context, :activity_bank_selections, %{})

    case Map.get(previews, selection_id) do
      nil ->
        Oli.Rendering.Content.Selection.render(context, selection, true)

      payload ->
        encoded_payload =
          payload
          |> Jason.encode!()
          |> HtmlEntities.encode()

        [
          ~s|<div id="#{JumpNavigation.selection_target_id(selection_id)}" class="instructor-preview-activity-bank-selection-wrapper mb-6 rounded-[12px] border border-Border-border-default bg-Surface-surface-primary overflow-hidden #{JumpNavigation.target_classes()}">|,
          ~s|<#{@element} payload="#{encoded_payload}"></#{@element}>|,
          ~s|</div>|
        ]
    end
  end

  defp build_sample_activity(
         nil,
         _section,
         _page_revision,
         _selection_id,
         _activity_type_by_id
       ),
       do: nil

  defp build_sample_activity(
         candidate,
         section,
         page_revision,
         selection_id,
         activity_type_by_id
       ) do
    revision = DeliveryResolver.from_resource_id(section.slug, candidate.activity_resource_id)

    case revision do
      %{activity_type_id: activity_type_id} = revision ->
        case Map.get(activity_type_by_id, activity_type_id) do
          activity_type when is_map(activity_type) ->
            {render_element, render_mode} = sample_render_target(activity_type)

            %{
              activityResourceId: revision.resource_id,
              title: revision.title,
              model: revision.content,
              previewElement: render_element,
              renderMode: render_mode,
              script: preview_script_for(activity_type),
              previewContext:
                build_sample_preview_context(
                  section,
                  page_revision,
                  selection_id,
                  revision,
                  activity_type
                )
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp sample_render_target(%{preview_element: preview_element}) when is_binary(preview_element),
    do: {preview_element, "preview"}

  defp sample_render_target(%{authoring_element: authoring_element})
       when is_binary(authoring_element),
       do: {authoring_element, "authoring_fallback"}

  defp sample_render_target(_activity_type), do: {nil, nil}

  defp build_sample_preview_context(
         section,
         page_revision,
         selection_id,
         activity_revision,
         activity_type
       ) do
    %{
      sectionSlug: section.slug,
      pageResourceId: page_revision.resource_id,
      pageRevisionSlug: page_revision.slug,
      activityResourceId: activity_revision.resource_id,
      activityHtmlId:
        Map.get(activity_revision.content, "id", "activity_#{activity_revision.resource_id}"),
      activityTypeSlug: activity_type.slug,
      activityTypeLabel: activity_type.title,
      title: activity_revision.title,
      points: Grading.determine_activity_out_of(activity_revision),
      learningObjectives: learning_objectives(section.id, activity_revision),
      canCustomize: false,
      actions: [],
      visualState: "default",
      statusPill: nil,
      customizationTarget: %{
        kind: "bank_candidate",
        pageResourceId: page_revision.resource_id,
        selectionId: selection_id,
        activityResourceId: activity_revision.resource_id
      }
    }
  end

  defp learning_objectives(section_id, activity_revision) do
    objective_ids = activity_objective_ids(activity_revision)

    case objective_ids do
      [] ->
        []

      objective_ids ->
        Oli.Delivery.Sections.SectionResourceDepot.objectives(section_id, [
          {:resource_id, {:in, objective_ids}}
        ])
        |> Map.new(fn objective -> {objective.resource_id, objective.title} end)
        |> then(fn titles_by_id ->
          objective_ids
          |> Enum.map(&Map.get(titles_by_id, &1))
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.sort()
        end)
    end
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

  defp activity_objective_ids(_activity_revision), do: []

  defp preview_script_for(%{
         preview_element: preview_element,
         preview_script: preview_script,
         authoring_script: authoring_script
       }) do
    if preview_element, do: preview_script || authoring_script, else: authoring_script
  end

  defp parse_selection(selection) do
    case Selection.parse(selection) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  defp points_per_activity(%Selection{points_per_activity: points_per_activity}, _selection),
    do: points_per_activity

  defp points_per_activity(_parsed_selection, selection),
    do: Map.get(selection, "pointsPerActivity", 1)

  defp select_count(%Selection{count: count}, _selection), do: count
  defp select_count(_parsed_selection, selection), do: Map.get(selection, "count", 0)

  defp actions(true), do: [%{kind: "remove", label: "Remove"}]
  defp actions(false), do: [%{kind: "restore", label: "Restore"}]

  defp manage_questions_url(section_slug, revision_slug, selection_id, navigation_params) do
    request_path = lesson_request_path(section_slug, revision_slug, navigation_params)

    params =
      navigation_params
      |> Map.take(["return_to"])
      |> Map.put("request_path", request_path)

    path =
      "/sections/#{section_slug}/preview/lesson/#{revision_slug}/selection/#{selection_id}"

    case Plug.Conn.Query.encode(params) do
      "" -> path
      query -> "#{path}?#{query}"
    end
  end

  defp lesson_request_path(section_slug, revision_slug, navigation_params) do
    path = "/sections/#{section_slug}/preview/lesson/#{revision_slug}"

    case navigation_params |> Map.take(["return_to"]) |> Plug.Conn.Query.encode() do
      "" -> path
      query -> "#{path}?#{query}"
    end
  end
end
