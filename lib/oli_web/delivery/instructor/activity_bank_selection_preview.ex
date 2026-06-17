defmodule OliWeb.Delivery.Instructor.ActivityBankSelectionPreview do
  @moduledoc false

  alias Oli.Activities.Realizer.Selection
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Grading
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Context
  alias Oli.Resources.PageContent

  @script "instructor_preview_components.js"
  @element "oli-activity-bank-selection-preview"

  def script, do: @script

  def build_preview_map(section, page_revision, activity_types) do
    selections =
      PageContent.flat_filter(page_revision.content, fn
        %{"type" => "selection", "id" => id} when is_binary(id) -> true
        _ -> false
      end)

    activity_type_by_id =
      Map.new(activity_types, fn activity_type -> {activity_type.id, activity_type} end)

    previews =
      selections
      |> Enum.map(fn selection ->
        {selection["id"], build_preview(section, page_revision, selection, activity_type_by_id)}
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

  def build_preview(section, page_revision, selection, activity_type_by_id) do
    selection_id = selection["id"]
    parsed_selection = parse_selection(selection)

    candidate_data =
      InstructorCustomizations.list_bank_selection_candidates(
        section,
        page_revision.resource_id,
        selection_id,
        limit: 1
      )

    {selection_enabled?, available_count, sample_activity} =
      case candidate_data do
        {:ok, %{selection_enabled?: enabled?, active_count: active_count, candidates: candidates}} ->
          effective_available_count = if enabled?, do: active_count, else: 0

          sample_activity =
            candidates
            |> List.first()
            |> build_sample_activity(
              section.slug,
              page_revision,
              selection_id,
              activity_type_by_id
            )

          {enabled?, effective_available_count, sample_activity}

        _ ->
          {true, 0, nil}
      end

    points_per_activity = points_per_activity(parsed_selection, selection)
    select_count = select_count(parsed_selection, selection)

    %{
      id: selection_id,
      title: "Activity Bank Selection",
      activityTypeLabel: "Activity Bank",
      pageResourceId: page_revision.resource_id,
      pageRevisionSlug: page_revision.slug,
      sectionSlug: section.slug,
      selectedCount: select_count,
      availableCount: available_count,
      pointsPerActivity: points_per_activity,
      criteria: criteria(selection),
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
          ~s|<div class="instructor-preview-activity-bank-selection-wrapper mb-6 rounded-lg border border-Border-border-default bg-Surface-surface-primary overflow-hidden">|,
          ~s|<#{@element} payload="#{encoded_payload}"></#{@element}>|,
          ~s|</div>|
        ]
    end
  end

  defp build_sample_activity(
         nil,
         _section_slug,
         _page_revision,
         _selection_id,
         _activity_type_by_id
       ),
       do: nil

  defp build_sample_activity(
         candidate,
         section_slug,
         page_revision,
         selection_id,
         activity_type_by_id
       ) do
    revision = DeliveryResolver.from_resource_id(section_slug, candidate.activity_resource_id)

    case revision do
      %{activity_type_id: activity_type_id} = revision ->
        case Map.get(activity_type_by_id, activity_type_id) do
          %{preview_element: preview_element} = activity_type when is_binary(preview_element) ->
            %{
              activityResourceId: revision.resource_id,
              title: revision.title,
              model: revision.content,
              previewElement: preview_element,
              script: preview_script_for(activity_type),
              previewContext:
                build_sample_preview_context(
                  section_slug,
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

  defp build_sample_preview_context(
         section_slug,
         page_revision,
         selection_id,
         activity_revision,
         activity_type
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
      learningObjectives: [],
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

  defp preview_script_for(%{
         preview_element: preview_element,
         preview_script: preview_script,
         authoring_script: authoring_script
       }) do
    if preview_element, do: preview_script || authoring_script, else: nil
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

  defp criteria(%{"logic" => %{"conditions" => nil}}), do: ["All activities"]
  defp criteria(%{"logic" => %{"conditions" => conditions}}), do: render_criteria(conditions)
  defp criteria(_selection), do: []

  defp render_criteria(items) when is_list(items), do: Enum.flat_map(items, &render_criteria/1)

  defp render_criteria(%{"children" => children, "operator" => operator}) do
    child_criteria = render_criteria(children)
    ["#{String.capitalize(to_string(operator))} of:" | child_criteria]
  end

  defp render_criteria(%{"fact" => fact, "operator" => operator, "value" => value}) do
    ["#{criterion_fact(fact)} #{criterion_operator(operator)} #{criterion_value(value)}"]
  end

  defp render_criteria(_), do: []

  defp criterion_fact("text"), do: "Activity text"
  defp criterion_fact("type"), do: "Activity type"
  defp criterion_fact("objectives"), do: "Learning objectives"
  defp criterion_fact("tags"), do: "Tags"
  defp criterion_fact(fact), do: to_string(fact)

  defp criterion_operator("contains"), do: "contains"
  defp criterion_operator("does_not_contain"), do: "does not contain"
  defp criterion_operator("equals"), do: "equals"
  defp criterion_operator("does_not_equal"), do: "does not equal"
  defp criterion_operator(operator), do: to_string(operator)

  defp criterion_value(value) when is_list(value), do: Enum.map_join(value, ", ", &to_string/1)
  defp criterion_value(value), do: to_string(value)
end
