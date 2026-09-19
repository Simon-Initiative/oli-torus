defmodule Oli.Delivery.Sections.LinkedActivities.PageContexts do
  @moduledoc """
  Indexes the delivery pages an activity appears on, for the instructor Linked Activities page.

  An activity's containing page is discoverable from two independent sources, and this module
  builds one index per source and merges them. It performs no queries: callers supply the
  section's page resources, their revisions, and the response pairs.
  """

  alias Oli.Resources.Revision

  @type t :: %{
          page_resource_id: integer(),
          page_revision: map()
        }

  @type index :: %{optional(integer()) => [t()]}

  @doc "Indexes the activity references a page revision declares, as written by the authoring editor."
  @spec from_activity_refs([map()], [Revision.t() | map()]) :: index()
  def from_activity_refs(page_resources, page_revisions) do
    revisions_by_id = Map.new(page_revisions, &{&1.id, &1})

    page_resources
    |> Enum.flat_map(fn page_resource ->
      case Map.get(revisions_by_id, page_resource.revision_id) do
        nil ->
          []

        page_revision ->
          page_revision
          |> Map.get(:activity_refs, [])
          |> List.wrap()
          |> Enum.map(&{&1, page_resource.resource_id})
      end
    end)
    |> from_page_pairs(page_resources, page_revisions)
  end

  @doc """
  Indexes `{activity_id, page_resource_id}` pairs, dropping pages absent from the section.

  Pairs are sorted first: `canonical/1` takes the head of each list, so the caller's order —
  a database result set with no `ORDER BY`, or a depot scan — must not decide which page the
  detail pane summarizes.
  """
  @spec from_page_pairs([{integer(), integer()}], [map()], [Revision.t() | map()]) :: index()
  def from_page_pairs(pairs, page_resources, page_revisions) do
    contexts_by_page = by_page_resource_id(page_resources, page_revisions)

    pairs
    |> Enum.sort()
    |> Enum.reduce(%{}, fn {activity_id, page_resource_id}, contexts ->
      case Map.get(contexts_by_page, page_resource_id) do
        nil -> contexts
        context -> Map.update(contexts, activity_id, [context], &(&1 ++ [context]))
      end
    end)
  end

  @doc "Merges two indexes, keeping the first one's order and dropping pages it already holds."
  @spec merge(index(), index()) :: index()
  def merge(primary, secondary) do
    Map.merge(primary, secondary, fn _activity_id, from_primary, from_secondary ->
      already_present = MapSet.new(from_primary, & &1.page_resource_id)

      from_primary ++
        Enum.reject(from_secondary, &MapSet.member?(already_present, &1.page_resource_id))
    end)
  end

  @doc "Selects the first stable page context for every activity."
  @spec canonical(index()) :: %{optional(integer()) => t()}
  def canonical(contexts) do
    Map.new(contexts, fn {activity_id, [context | _]} -> {activity_id, context} end)
  end

  defp by_page_resource_id(page_resources, page_revisions) do
    revisions_by_id = Map.new(page_revisions, &{&1.id, &1})

    Enum.reduce(page_resources, %{}, fn page_resource, index ->
      case Map.get(revisions_by_id, page_resource.revision_id) do
        nil ->
          index

        page_revision ->
          Map.put(index, page_resource.resource_id, %{
            page_resource_id: page_resource.resource_id,
            page_revision: page_revision
          })
      end
    end)
  end
end
