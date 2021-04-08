defmodule Oli.Authoring.Editing.Utils do
  alias Oli.Accounts

  def authorize_user(author, project) do
    case Accounts.can_access?(author, project) do
      true -> {:ok}
      false -> {:error, {:not_authorized}}
    end
  end

  def trap_nil(result) do
    case result do
      nil -> {:error, {:not_found}}
      _ -> {:ok, result}
    end
  end

  @doc """
  Calculates the difference in the activities references between
  two pieces of content.

  Returns a two element tuple, the first element being a mapset of
  the resource ids of activities are present in content2 but were
  not found in content1, and the second being a mapset of the resource
  ids of activities not found in content2 but there were found in content1
  """
  def diff_activity_references(content1, content2) do
    activities1 = activity_references(content1)
    activities2 = activity_references(content2)

    {MapSet.difference(activities2, activities1), MapSet.difference(activities1, activities2)}
  end

  def activity_references(content) do
    case content do
      nil ->
        MapSet.new()

      [] ->
        MapSet.new()

      _ ->
        Enum.filter(content, fn %{"type" => type} -> type == "activity-reference" end)
        |> Enum.map(fn %{"activity_id" => id} -> id end)
        |> MapSet.new()
    end
  end
end
