defmodule Oli.Delivery.PreviousNextIndex do
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Hierarchy
  alias Oli.Resources.Numbering
  alias Oli.Repo

  @doc """
  For a given section slug and a resource id of a page or container within the section hierarchy, returns the
  link descriptors for the previous, next and current resources.  This function will rebuild the previous_next_index
  if it is nil.  This allows a just-in-time update for actions that invalidate this structure.

  Returns a nested tuple of the form:
  {:ok, {previous, next, current}, previous_next_index} where previous, next, current are all link descriptors.  A link descriptor
  is of the form:

  %{
    "id" => "3",
    "type" => "page",
    "index" => "1",
    "level" => "2",
    "prev" => "2",
    "next" => "4",
    "slug => "the_slug",
    "title" => "The title",
    "children" => []
  }

  Returns {:error, reason} if the index cannot be rebuilt.

  """
  def retrieve(section, resource_id, opts \\ [skip: []])

  def retrieve(%Section{previous_next_index: nil} = section, resource_id, opts) do
    case rebuild_if_nil(section) do
      {:ok, section} -> retrieve(section, resource_id, opts)
      {:error, e} -> Repo.rollback(e)
    end
  end

  def retrieve(%Section{previous_next_index: previous_next_index}, resource_id, opts) do
    retrieve(previous_next_index, resource_id, opts)
  end

  def retrieve(previous_next_index, resource_id, skip: containers_to_skip)
      when is_map(previous_next_index) and containers_to_skip != [] do
    case Map.get(previous_next_index, Integer.to_string(resource_id)) do
      nil ->
        {:ok, {nil, nil, nil}, previous_next_index}

      %{"prev" => prev, "next" => next} = current ->
        {:ok,
         {get_closest_navigable_resource(previous_next_index, prev, "prev", containers_to_skip),
          get_closest_navigable_resource(previous_next_index, next, "next", containers_to_skip),
          current}, previous_next_index}
    end
  end

  def retrieve(previous_next_index, resource_id, _opts) when is_map(previous_next_index) do
    case Map.get(previous_next_index, Integer.to_string(resource_id)) do
      nil ->
        {:ok, {nil, nil, nil}, previous_next_index}

      %{"prev" => nil, "next" => next} = current ->
        {:ok, {nil, Map.get(previous_next_index, next), current}, previous_next_index}

      %{"prev" => prev, "next" => nil} = current ->
        {:ok, {Map.get(previous_next_index, prev), nil, current}, previous_next_index}

      %{"prev" => prev, "next" => next} = current ->
        {:ok, {Map.get(previous_next_index, prev), Map.get(previous_next_index, next), current},
         previous_next_index}
    end
  end

  defp get_closest_navigable_resource(
         _previous_next_index,
         nil,
         _direction,
         _containers_to_skip
       ),
       do: nil

  defp get_closest_navigable_resource(
         previous_next_index,
         current_resource_id,
         direction,
         containers_to_skip
       ) do
    current_resource = Map.get(previous_next_index, current_resource_id)

    with %{"type" => "container", "level" => level} <- current_resource,
         {level, _} <- Integer.parse(level),
         true <- skip_container?(level, containers_to_skip) do
      get_closest_navigable_resource(
        previous_next_index,
        current_resource[direction],
        direction,
        containers_to_skip
      )
    else
      _ -> current_resource
    end
  end

  defp skip_container?(1, [:unit | _containers]), do: true
  defp skip_container?(2, [:module | _containers]), do: true
  defp skip_container?(level, [:section | _containers]) when level > 2, do: true
  defp skip_container?(level, [_container | containers]), do: skip_container?(level, containers)
  defp skip_container?(_level, []), do: false

  # Allowing the section to be directly passed in from client code is problematic because it
  # can lead to situations where client code is continually passing in a %Section{} with a
  # previous_next_index that is nil, causing the "just in time" rebuild mechanism to execute
  # over and over, when it does not need to.  So instead, when the index is nil we refetch the
  # section to see if simply a stale section was given.  If the index is still nil, we then rebuild.
  defp rebuild_if_nil(section) do
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
           {new_hierarchy, _} = DeliveryResolver.full_hierarchy(slug)
           |> Numbering.renumber_hierarchy()

           Hierarchy.build_navigation_link_map(new_hierarchy)
           |> then(fn previous_next_index ->
             Sections.update_section(section, %{previous_next_index: previous_next_index})
           end)
         end) do
      {:ok, result} -> result
      {:error, e} -> e
    end
  end

  def rebuild(%Section{} = section, hierarchy) do
    case Repo.transaction(fn _ ->
           Hierarchy.build_navigation_link_map(hierarchy)
           |> then(fn previous_next_index ->
             Sections.update_section(section, %{previous_next_index: previous_next_index})
           end)
         end) do
      {:ok, result} -> result
      {:error, e} -> e
    end
  end
end
