defmodule OliWeb.Curriculum.Rollup do

  alias OliWeb.Curriculum.ActivityDelta
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Publishing.AuthoringResolver

  defstruct page_activity_map: %{},
    activity_map: %{},
    objective_map: %{}

  def new(pages, project_slug) do

    page_activity_map = build_activity_to_page_map(pages)
    activity_map = build_activity_map(project_slug, page_activity_map)
    objective_map = build_objective_map(project_slug, activity_map)

    {:ok, %__MODULE__{page_activity_map: page_activity_map, activity_map: activity_map, objective_map: objective_map}}
  end

  def page_updated(%__MODULE__{} = struct,
    %Revision{} = revision,
    %ActivityDelta{added: added, deleted: deleted, current: current},
    project_slug) do

    # capture the updated page to activity mapping
    page_activity_map = Map.put(struct.page_activity_map, revision.resource_id, MapSet.to_list(current))

    # remove any activities that have been deleted
    activity_map = Enum.reduce(deleted, struct.activity_map, fn id, m -> Map.delete(m, id) end)

    {activity_map, objective_map} = case added do

      [] -> {activity_map, struct.objective_map}

      _ ->

        resolved_activities = AuthoringResolver.from_resource_id(project_slug, added)

        partial_activity_map = resolved_activities
        |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)

        activity_map = Map.merge(activity_map, partial_activity_map)

        objective_map = Map.merge(struct.objective_map, build_objective_map(project_slug, partial_activity_map))

        {activity_map, objective_map}
    end

    %__MODULE__{
      page_activity_map: page_activity_map,
      activity_map: activity_map,
      objective_map: objective_map
    }

  end

  def activity_updated(%__MODULE__{} = struct, %Revision{} = revision, project_slug) do

    old_activity = Map.get(struct.activity_map, revision.resource_id)

    get_objectves = fn %{objectives: objectives} -> (Enum.map(objectives, fn {_, ids} -> ids end) |> List.flatten() |> MapSet.new()) end

    old_objectives = get_objectves.(old_activity)
    updated_objectives = get_objectves.(revision)

    # we only need to update the rollup when the objectives attached to this
    # activity have changed.  If they haven't changed, we can ignore this update
    if MapSet.equal?(old_objectives, updated_objectives) do
      struct
    else

      activity_map = Map.put(struct.activity_map, revision.resource_id, revision)

      partial_activity_map = Map.put(%{}, revision.resource_id, revision)
      objective_map = Map.merge(struct.objective_map, build_objective_map(project_slug, partial_activity_map))

      %__MODULE__{
        page_activity_map: struct.page_activity_map,
        activity_map: activity_map,
        objective_map: objective_map
      }
    end

  end

  def objective_updated(%__MODULE__{} = struct, %Revision{} = revision) do
    %__MODULE__{
      page_activity_map: struct.page_activity_map,
      activity_map: struct.activity_map,
      objective_map: Map.put(struct.objective_map, revision.resource_id, revision)
    }
  end

  def have_activities_changed(added_activities, deleted_activities) do
    length(deleted_activities) > 0 or length(added_activities) > 0
  end

  # creates a map of page resource ids to a list of the activity ids for the activities
  # that they contain
  defp build_activity_to_page_map(pages) do

    Enum.reduce(pages, %{}, fn %{resource_id: page_id} = revision, map ->

      activities = get_activities_from_page(revision)
      Map.put(map, page_id, activities)
    end)

  end

  # extract all the activity ids referenced from a page model
  defp get_activities_from_page(revision) do
    Resources.activity_references(revision)
  end

  # creates a map of activity ids to activity revisions, based on the page_to_activities_map
  defp build_activity_map(project_slug, page_to_activities_map) do
    all_activities = Enum.map(page_to_activities_map, fn {_, activity_ids} -> activity_ids end)
    |> List.flatten()

    AuthoringResolver.from_resource_id(project_slug, all_activities)
    |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)
  end

  # creates a map of objective ids to objective revisions, based on the activity map
  defp build_objective_map(project_slug, activity_map) do
    all_objectives = Enum.reduce(activity_map, [], fn {_, %{objectives: objectives}}, all ->
      (Enum.map(objectives, fn {_, ids} -> ids end) |> List.flatten()) ++ all
    end)

    AuthoringResolver.from_resource_id(project_slug, all_objectives)
    |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a) end)

  end

end
