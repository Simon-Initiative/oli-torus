defmodule OliWeb.Delivery.Instructor.ActivityBankSelectionPreview do
  @moduledoc false

  alias Oli.Activities
  alias Oli.Activities.Realizer.Selection
  alias Oli.Activities.Realizer.Logic.{Clause, Expression}
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Grading
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Content.JumpNavigation
  alias Oli.Rendering.Context
  alias Oli.Resources
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

    %{
      id: selection_id,
      title: "Activity Bank Selection",
      activityTypeLabel: "Activity Bank",
      pageResourceId: page_revision.resource_id,
      pageRevisionSlug: page_revision.slug,
      sectionSlug: section.slug,
      selectedCount: select_count,
      availableCount: available_count,
      originalAvailableCount: original_available_count,
      pointsPerActivity: points_per_activity,
      criteria: criteria(parsed_selection, section.slug),
      manageQuestionsUrl: nil,
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
        SectionResourceDepot.objectives(section_id, [{:resource_id, {:in, objective_ids}}])
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

  defp criteria(%Selection{logic: %{conditions: nil}}, _section_slug),
    do: []

  defp criteria(%Selection{logic: %{conditions: conditions}}, section_slug) do
    conditions
    |> collect_criteria(section_slug)
    |> Enum.reduce([], fn {label, values}, groups ->
      merge_criteria_group(groups, label, values)
    end)
  end

  defp criteria(_selection, _section_slug), do: []

  defp collect_criteria(%Clause{children: children}, section_slug),
    do: Enum.flat_map(children, &collect_criteria(&1, section_slug))

  defp collect_criteria(%Expression{fact: :tags, operator: operator, value: values}, section_slug)
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Tags",
       labels_for_resource_ids(values, section_slug)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :objectives, operator: operator, value: values},
         section_slug
       )
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Learning Objectives",
       labels_for_resource_ids(values, section_slug)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :type, operator: operator, value: values},
         _section_slug
       )
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Activity Types",
       labels_for_activity_type_ids(values)}
    ]
  end

  defp collect_criteria(%Expression{} = expression, _section_slug) do
    [
      {"#{criteria_exclusion_prefix(expression.operator)}Other",
       [criterion_value(expression.value)]}
    ]
  end

  defp collect_criteria(_condition, _section_slug), do: []

  defp merge_criteria_group(groups, label, values) do
    case Enum.find_index(groups, &(&1.label == label)) do
      nil ->
        groups ++ [%{label: label, values: Enum.uniq(values)}]

      index ->
        List.update_at(groups, index, fn group ->
          %{group | values: Enum.uniq(group.values ++ values)}
        end)
    end
  end

  defp criteria_exclusion_prefix(operator)
       when operator in [:does_not_contain, :does_not_equal, "does_not_contain", "does_not_equal"],
       do: "Excluded "

  defp criteria_exclusion_prefix(_operator), do: ""

  defp labels_for_resource_ids(resource_ids, section_slug) do
    Enum.map(resource_ids, fn resource_id ->
      case resource_label(resource_id, section_slug) do
        nil -> to_string(resource_id)
        label -> label
      end
    end)
  end

  defp labels_for_activity_type_ids(activity_type_ids) do
    registrations_by_id =
      Activities.list_activity_registrations()
      |> Map.new(fn registration -> {registration.id, registration.title} end)

    Enum.map(activity_type_ids, fn activity_type_id ->
      Map.get(registrations_by_id, activity_type_id, to_string(activity_type_id))
    end)
  end

  defp resource_label(resource_id, section_slug) do
    case Resources.resource_summary(resource_id, section_slug, DeliveryResolver) do
      %{title: title} when is_binary(title) -> title
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp criterion_value(value) when is_list(value), do: Enum.map_join(value, ", ", &to_string/1)
  defp criterion_value(value), do: to_string(value)
end
