defmodule Oli.Delivery.PreviousNextIndex do
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Hierarchy
  alias Oli.Repo

  @doc """
  For a given section slug and a resource id of a page within the section hiearchy, returns the
  link descriptors for the previous and next pages.  This function will rebuild the previous_next_index
  if it is nil.  This allows a just-in-time update for actions that invalidate this structure.

  Returns a tuple of the form:
  {:ok, {previous, next}} where previous and next are both link descriptors.  A link descriptor
  is of the form:

  %{
    "prev" => "2",
    "next" => "4",
    "slug => "the_slug",
    "title" => "The title"
  }

  Returns {:error, reason} if the index cannot be rebuilt.

  """
  def retrieve(%Section{previous_next_index: nil} = section, resource_id) do
    case rebuild_if_not_nil(section) do
      {:ok, section} -> retrieve(section, resource_id)
      {:error, e} -> Repo.rollback(e)
    end
  end

  def retrieve(%Section{previous_next_index: previous_next_index}, resource_id) do
    case Map.get(previous_next_index, Integer.to_string(resource_id)) do
      nil ->
        {:ok, {nil, nil}}

      %{"prev" => nil, "next" => next} ->
        {:ok, {nil, Map.get(previous_next_index, next)}}

      %{"prev" => prev, "next" => nil} ->
        {:ok, {Map.get(previous_next_index, prev), nil}}

      %{"prev" => prev, "next" => next} ->
        {:ok, {Map.get(previous_next_index, prev), Map.get(previous_next_index, next)}}
    end
  end

  # Allowing the section to be directly passed in from client code is problematic because it
  # can lead to situations where client code is continually passing in a %Section{} with a
  # previous_next_index that is nil, causing the "just in time" rebuild mechanism to execute
  # over and over, when it does not need to.  So instead, when the index is nil we refetch the
  # section to see if simply a stale section was given.  If the index is still nil, we then rebuild.
  defp rebuild_if_not_nil(section) do
    case Sections.get_section_by(slug: section.slug) do
      %{previous_next_index: nil} -> rebuild(section)
      section -> {:ok, section}
    end
  end

  @doc """
  Rebuilds the previous_next_index for the given %Section{}, updating the section
  with the newly rebuilt index.
  """
  def rebuild(%Section{slug: slug} = section) do
    case Repo.transaction(fn _ ->
           DeliveryResolver.full_hierarchy(slug)
           |> Hierarchy.build_navigation_link_map()
           |> then(fn previous_next_index ->
             Sections.update_section(section, %{previous_next_index: previous_next_index})
           end)
         end) do
      {:ok, result} -> result
      {:error, e} -> e
    end
  end
end
