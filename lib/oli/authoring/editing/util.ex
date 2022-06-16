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

  @doc """
  Returns a MapSet of all activity ids found in the page content hierarchy.
  """
  def activity_references(content) do
    case content do
      %{"model" => _} ->
        Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
          type == "activity-reference"
        end)
        |> Enum.map(fn %{"activity_id" => id} -> id end)
        |> MapSet.new()

      _ ->
        MapSet.new([])
    end
  end

  @doc """
  Returns a MapSet of all bib_entry_id ids found in the page content hierarchy.
  """
  def citation_references(content) do
    case content do
      %{"model" => _} ->
        Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
          type == "cite"
        end)
        |> Enum.map(fn %{"bib_entry_id" => id} -> id end)
        |> MapSet.new()

      _ ->
        MapSet.new([])
    end
  end

  @doc """
  Assembles all of the bibliography references from a page and the activities that are
  contained within it.  Returns a list of the unique revisions of the bibliography
  entries, resolved using the supplied resolver.
  """
  def assemble_bib_entries(content, activities, activity_bib_provider_fn, section_slug, resolver) do
    page_bib_ids =
      Map.get(content, "bibrefs", [])
      |> Enum.map(fn x -> Map.get(x, "id") end)

    activity_bib_ids =
      Enum.map(activities, fn a -> activity_bib_provider_fn.(a) end)
      |> Enum.map(fn bib -> Enum.map(bib, fn b -> Map.get(b, "id") end) end)
      |> List.flatten()

    all_unique_bib_ids =
      MapSet.new(page_bib_ids ++ activity_bib_ids)
      |> MapSet.to_list()

    resolver.from_resource_id(section_slug, all_unique_bib_ids)
  end
end
