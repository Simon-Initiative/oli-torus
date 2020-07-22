defmodule Oli.Delivery.Page.ObjectivesRollup do

  # for a map of activity ids to latest attempt tuples (where the first tuple item is the activity attempt)
  # return the parent objective revisions of all attached objectives
  # if an attached objective is a parent, include that in the return list
  def rollup_objectives(activity_revisions, resolver, context_id) do

    attached_objective_ids = Enum.reduce(activity_revisions, MapSet.new(), fn %{objectives: objectives}, all ->
        Enum.map(objectives, fn {_, ids} -> ids end)
        |> List.flatten
        |> MapSet.new
        |> MapSet.union(all)
      end)
    |> MapSet.to_list

    all = resolver.from_resource_id(context_id, attached_objective_ids)

    parents = resolver.find_parent_objectives(context_id, attached_objective_ids)

    # now we have revisions for all directly attached objectives and their parents (if they have parents)
    # we want to only return the parents

    # create a map set of all referenced children
    referenced_children = Enum.reduce(parents, MapSet.new(), fn %{children: children}, m ->
      Enum.reduce(children, m, fn id, m -> MapSet.put(m, id) end)
    end)

    # now look at all directly attached objectives.  If one does not exist within the set of referenced
    # children that means that is a root objective that was directly attached, so we append it to
    # the parents collection
    Enum.reduce(all, parents, fn r, items ->
      case MapSet.member?(referenced_children, r.resource_id) do
        true -> items
        false -> [r] ++ items
      end
    end)
    |> Enum.map(fn r -> r.title end)
    |> MapSet.new
    |> MapSet.to_list()
    |> Enum.sort

  end


end
