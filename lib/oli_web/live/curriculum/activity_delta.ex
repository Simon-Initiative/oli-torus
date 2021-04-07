defmodule OliWeb.Curriculum.ActivityDelta do
  alias Oli.Resources

  defstruct current: nil,
            deleted: [],
            added: []

  def new(current_page, old_page) do
    current = get_activities_from_page(current_page) |> MapSet.new()
    previous_activities = get_activities_from_page(old_page) |> MapSet.new()

    deleted = MapSet.difference(previous_activities, current) |> MapSet.to_list()
    added = MapSet.difference(current, previous_activities) |> MapSet.to_list()

    {:ok, %__MODULE__{current: current, deleted: deleted, added: added}}
  end

  def have_activities_changed?(%__MODULE__{} = struct) do
    length(struct.added) > 0 or length(struct.deleted) > 0
  end

  # extract all the activity ids referenced from a page model
  defp get_activities_from_page(revision) do
    Resources.activity_references(revision)
  end
end
