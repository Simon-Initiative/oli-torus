defmodule Oli.Authoring.ObjectiveCoverage.CsvExport do
  @moduledoc """
  Produces the authoring learning-objective map CSV from the compact
  `Oli.Authoring.ObjectiveCoverage` snapshot.

  Activity data comes from the snapshot's projection, which deliberately omits
  revision content. Curriculum locations are derived once from its precomputed
  page paths and then reused for every exported relationship.
  """

  alias Oli.Activities
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.ObjectiveCoverage
  alias Oli.Branding.CustomLabels
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

  @headers [
    "LO Label",
    "LO Title",
    "Sub-Objective",
    "Activity Type",
    "Activity Name",
    "Page Name",
    "Course Location"
  ]

  @type export_row :: [String.t()]

  @doc "Returns the ordered CSV column headers."
  @spec headers() :: [String.t()]
  def headers, do: @headers

  @doc "Loads a project's compact coverage snapshot and encodes its CSV."
  @spec generate(%Project{}, map()) :: {:ok, String.t()} | {:error, atom()}
  def generate(%Project{} = project, params \\ %{}) do
    with {:ok, model} <- ObjectiveCoverage.load(project) do
      activity_types_by_id =
        Activities.list_activity_registrations()
        |> Map.new(&{&1.id, &1.title})

      {:ok, encode(model, project.customizations, activity_types_by_id, params)}
    end
  end

  @doc "Encodes a previously loaded coverage snapshot as CSV."
  @spec encode(ObjectiveCoverage.t(), %CustomLabels{} | nil, map(), map()) :: String.t()
  def encode(model, customizations, activity_types_by_id, params \\ %{}) do
    model
    |> rows(customizations, activity_types_by_id, params)
    |> then(&[@headers | &1])
    |> CSV.encode()
    |> Enum.join()
  end

  @doc "Builds ordered, spreadsheet-safe export rows without encoding them."
  @spec rows(ObjectiveCoverage.t(), %CustomLabels{} | nil, map(), map()) :: [export_row()]
  def rows(model, customizations, activity_types_by_id, params \\ %{}) do
    activities_by_objective = activities_by_objective(model.activities_by_id)
    pages_by_activity = pages_by_activity(model.pages_by_id)
    course_locations = course_locations(model, customizations)

    model
    |> filtered_and_sorted_objectives(params, activities_by_objective)
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {objective, index} ->
      relationship_rows(
        model,
        objective,
        index,
        activities_by_objective,
        pages_by_activity,
        course_locations,
        activity_types_by_id
      )
    end)
    |> Enum.map(fn row -> Enum.map(row, &spreadsheet_safe/1) end)
  end

  defp filtered_and_sorted_objectives(model, params, activities_by_objective) do
    query = params |> param("query", "") |> normalize_text()

    objectives =
      model
      |> ObjectiveCoverage.objectives()
      |> Enum.filter(fn objective ->
        query == "" or String.contains?(normalize_text(objective.title), query)
      end)

    sort_by = param(params, "sort_by", "title")
    sort_order = if param(params, "sort_order", "asc") == "desc", do: :desc, else: :asc

    Enum.sort_by(
      objectives,
      &objective_sort_value(model, &1, sort_by, activities_by_objective),
      sort_order
    )
  end

  defp objective_sort_value(_model, objective, "title", _activities_by_objective),
    do: {normalize_text(objective.title), objective.resource_id}

  defp objective_sort_value(model, objective, "sub_objectives_count", _activities_by_objective) do
    coverage = ObjectiveCoverage.coverage(model, objective.resource_id)
    {coverage.sub_objective_count, normalize_text(objective.title), objective.resource_id}
  end

  defp objective_sort_value(model, objective, "page_attachments_count", _activities_by_objective) do
    page_count =
      [objective.resource_id | Map.get(model.children_by_parent, objective.resource_id, [])]
      |> Enum.flat_map(&Map.get(model.direct_page_ids_by_objective, &1, []))
      |> Enum.uniq()
      |> length()

    {page_count, normalize_text(objective.title), objective.resource_id}
  end

  defp objective_sort_value(
         _model,
         objective,
         "activity_attachments_count",
         activities_by_objective
       ) do
    activity_count =
      activities_by_objective
      |> Map.get(objective.resource_id, [])
      |> Enum.map(& &1.resource_id)
      |> Enum.uniq()
      |> length()

    {activity_count, normalize_text(objective.title), objective.resource_id}
  end

  defp objective_sort_value(_model, objective, _sort_by, _activities_by_objective),
    do: {normalize_text(objective.title), objective.resource_id}

  defp relationship_rows(
         model,
         objective,
         index,
         activities_by_objective,
         pages_by_activity,
         course_locations,
         activity_types_by_id
       ) do
    model.objective_scope_by_id
    |> Map.get(objective.resource_id, [objective.resource_id])
    |> Enum.filter(&Map.has_key?(model.objectives_by_id, &1))
    |> Enum.sort_by(fn objective_id ->
      related_objective = Map.fetch!(model.objectives_by_id, objective_id)

      {
        if(objective_id == objective.resource_id, do: 0, else: 1),
        normalize_text(related_objective.title),
        objective_id
      }
    end)
    |> Enum.flat_map(fn related_objective_id ->
      sub_objective_title =
        if related_objective_id == objective.resource_id do
          ""
        else
          model.objectives_by_id[related_objective_id].title || ""
        end

      activities_by_objective
      |> Map.get(related_objective_id, [])
      |> Enum.sort_by(&{normalize_text(&1.title), &1.resource_id})
      |> Enum.flat_map(fn activity ->
        activity_pages = Map.get(pages_by_activity, activity.resource_id, [])
        activity_pages = if activity_pages == [], do: [nil], else: activity_pages

        Enum.map(activity_pages, fn page ->
          [
            "LO #{index}",
            objective.title || "",
            sub_objective_title,
            Map.get(activity_types_by_id, activity.activity_type_id, ""),
            activity.title || "",
            page_title(page),
            page_location(page, course_locations)
          ]
        end)
      end)
    end)
  end

  defp activities_by_objective(activities_by_id) do
    Enum.reduce(activities_by_id, %{}, fn {_activity_id, activity}, acc ->
      activity.objectives
      |> objective_ids()
      |> Enum.reduce(acc, fn objective_id, acc ->
        Map.update(acc, objective_id, [activity], &[activity | &1])
      end)
    end)
  end

  defp pages_by_activity(pages_by_id) do
    Enum.reduce(pages_by_id, %{}, fn {_page_id, page}, acc ->
      Enum.reduce(page.activity_refs, acc, fn activity_id, acc ->
        Map.update(acc, activity_id, [page], &[page | &1])
      end)
    end)
    |> Map.new(fn {activity_id, pages} ->
      {activity_id, Enum.sort_by(pages, &{normalize_text(&1.title), &1.resource_id})}
    end)
  end

  defp course_locations(model, customizations) do
    labels = custom_labels(customizations)
    numberings = curriculum_numberings(model, labels)
    container_type_id = ResourceType.id_for_container()

    Map.new(model.pages_by_id, fn {page_id, _page} ->
      location =
        model.curriculum_paths_by_id
        |> Map.get(page_id, [])
        |> course_path(model.root_resource_id)
        |> Enum.flat_map(fn resource_id ->
          with %{resource_type_id: ^container_type_id} = container <-
                 Map.get(model.curriculum_by_id, resource_id),
               %Numbering{} = numbering <- Map.get(numberings, resource_id) do
            ["#{Numbering.prefix(numbering)}: #{container.title}"]
          else
            _ -> []
          end
        end)
        |> Enum.join(" > ")

      {page_id, location}
    end)
  end

  defp course_path(paths, root_resource_id) do
    Enum.find(paths, &(List.first(&1) == root_resource_id)) || List.first(paths) || []
  end

  defp curriculum_numberings(model, labels) do
    root_ids = curriculum_root_ids(model)

    {_tracker, numberings} =
      Enum.reduce(root_ids, {Numbering.init_numbering_tracker(), %{}}, fn root_id, acc ->
        number_children(model.curriculum_by_id, root_id, 1, labels, acc, MapSet.new())
      end)

    numberings
  end

  defp curriculum_root_ids(model) do
    case Map.fetch(model.curriculum_by_id, model.root_resource_id) do
      {:ok, _root} ->
        [model.root_resource_id]

      :error ->
        model.curriculum_by_id
        |> Map.keys()
        |> Enum.reject(&Map.has_key?(model.curriculum_parents_by_child, &1))
        |> Enum.sort()
    end
  end

  defp number_children(curriculum_by_id, parent_id, level, labels, acc, visiting) do
    parent = Map.fetch!(curriculum_by_id, parent_id)
    visiting = MapSet.put(visiting, parent_id)

    parent.ordered_children
    |> Enum.filter(&Map.has_key?(curriculum_by_id, &1))
    |> Enum.reduce(acc, fn child_id, acc ->
      case MapSet.member?(visiting, child_id) do
        true ->
          acc

        false ->
          child = Map.fetch!(curriculum_by_id, child_id)
          {tracker, numberings} = acc
          {index, tracker} = Numbering.next_index(tracker, level, child)
          numbering = %Numbering{level: level, index: index, labels: labels}

          number_children(
            curriculum_by_id,
            child_id,
            level + 1,
            labels,
            {tracker, Map.put(numberings, child_id, numbering)},
            visiting
          )
      end
    end)
  end

  defp custom_labels(nil), do: CustomLabels.default_map()

  defp custom_labels(%CustomLabels{} = customizations) do
    defaults = CustomLabels.default_map()

    customizations
    |> Map.from_struct()
    |> Map.take([:unit, :module, :section])
    |> Map.merge(defaults, fn _key, custom, default -> custom || default end)
  end

  defp objective_ids(objectives) when is_map(objectives) do
    objectives
    |> Map.values()
    |> Enum.flat_map(&List.wrap/1)
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
  end

  defp objective_ids(_), do: []

  defp page_title(nil), do: ""
  defp page_title(page), do: page.title || ""

  defp page_location(nil, _course_locations), do: ""
  defp page_location(page, course_locations), do: Map.get(course_locations, page.resource_id, "")

  defp param(params, key, default),
    do: Map.get(params, key, Map.get(params, String.to_existing_atom(key), default))

  defp normalize_text(value) when is_binary(value),
    do: value |> String.downcase() |> String.trim()

  defp normalize_text(_), do: ""

  # Prevent user-authored titles from being interpreted as formulas by common
  # spreadsheet applications while preserving their visible text.
  defp spreadsheet_safe(value) when is_binary(value) do
    case String.trim_leading(value) do
      <<prefix::binary-size(1), _::binary>> when prefix in ["=", "+", "-", "@"] ->
        "'" <> value

      _ ->
        value
    end
  end

  defp spreadsheet_safe(value), do: to_string(value || "")
end
