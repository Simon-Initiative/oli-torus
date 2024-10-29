defmodule Oli.Resources.PageContent do
  alias Oli.Resources.PageContent.TraversalContext

  import Oli.Utils, only: [ensure_number_is_string: 1]

  @doc """
  Modelled after `Enum.map_reduce`, this invokes the given function to each content element in a page content tree.

  Returns a tuple where the first element is the mapped page content tree
  and the second one is the final accumulator.

  The function, map_fn, receives three arguments: the first one is the element, the second is the accumulator
  and the third is a traversal context struct `%TraversalContext{}` which contains information about the
  current element such as group or survey id.
  map_fn must return a tuple with two elements in the form of {mapped content element, accumulator}.
  """
  def map_reduce(content, acc, map_fn, tr_context \\ %TraversalContext{})

  def map_reduce(%{"model" => model} = content, acc, map_fn, tr_context) do
    {items, acc} =
      Enum.reduce(model, {[], acc}, fn item, {items, acc} ->
        {item, acc} = map_reduce(item, acc, map_fn, %TraversalContext{tr_context | level: 1})

        {items ++ [item], acc}
      end)

    {Map.put(content, "model", items), acc}
  end

  def map_reduce(%{"type" => "content"} = content, acc, map_fn, tr_context) do
    map_fn.(content, acc, tr_context)
  end

  def map_reduce(%{"type" => "group", "id" => group_id} = content, acc, map_fn, tr_context) do
    item_with_children(content, acc, map_fn, %TraversalContext{tr_context | group_id: group_id})
  end

  def map_reduce(%{"type" => "survey", "id" => survey_id} = content, acc, map_fn, tr_context) do
    item_with_children(content, acc, map_fn, %TraversalContext{tr_context | survey_id: survey_id})
  end

  def map_reduce(%{"children" => _children} = item, acc, map_fn, tr_context) do
    item_with_children(item, acc, map_fn, tr_context)
  end

  def map_reduce(item, acc, map_fn, tr_context) do
    map_fn.(item, acc, tr_context)
  end

  defp item_with_children(%{"children" => _children} = item, acc, map_fn, tr_context) do
    map_reduce_property = fn {item, acc}, property ->
      children = Map.get(item, property)

      if is_list(children) do
        {mapped_children, acc} =
          Enum.reduce(children, {[], acc}, fn item, {items, acc} ->
            {item, acc} =
              map_reduce(item, acc, map_fn, %TraversalContext{
                tr_context
                | level: tr_context.level + 1
              })

            {items ++ [item], acc}
          end)

        {Map.put(item, property, mapped_children), acc}
      else
        {item, acc}
      end
    end

    # must process content in certain properties as well as children
    # definition meanings has list of meaning elements w/content in children
    props = ["children", "caption", "pronunciation", "translations", "content", "meanings"]

    {item, acc} =
      Enum.reduce(props, {item, acc}, fn prop, {item, acc} ->
        map_reduce_property.({item, acc}, prop)
      end)

    map_fn.(item, acc, tr_context)
  end

  @doc """
  Flattens and filters the page content elements into a list. Implemented as a
  convenience function, over top of map_reduce.
  """
  def flat_filter(%{"model" => _model} = content, filter_fn) do
    {_, filtered} =
      map_reduce(
        content,
        [],
        fn e, filtered, _tr_context ->
          if filter_fn.(e) do
            {e, filtered ++ [e]}
          else
            {e, filtered}
          end
        end
      )

    filtered
  end

  @doc """
  Maps the content elements of page content, preserving the as-is structure. Implemented as a
  convenience function, over top of map_reduce.
  """
  def map(%{"model" => _model} = content, map_fn) do
    {mapped, _} = map_reduce(content, 0, fn e, _acc, _tr_context -> {map_fn.(e), 0} end)

    mapped
  end

  @doc """
  Finds all activities contained in the given page content hierarchy and reduces a map of
  activity resource ids to a map containing group and survey keys that indicate the
  parent group and/or survey identifiers of the activity.

  Useful for determining if an activity exists in a group or survey.

  ## Examples
      iex> activity_parent_groups(content)
      %{
        10 => %{group: "44325", survey: nil},        # inside a group
        11 => %{group: nil, survey: "92374"},        # inside a survey
        23 => %{group: "53222", survey: "96366"},    # inside a group and a survey
        26 => %{group: nil, survey: nil},            # not inside a group or survey
      }
  """
  def activity_parent_groups(%{"model" => _model} = content) do
    map_reduce(
      content,
      %{},
      fn el, activity_groups, %TraversalContext{group_id: group_id, survey_id: survey_id} ->
        case el do
          %{"type" => "activity-reference", "activity_id" => activity_id} ->
            {el,
             Map.put_new(activity_groups, activity_id, %{
               group: ensure_number_is_string(group_id),
               survey: ensure_number_is_string(survey_id)
             })}

          %{"type" => "selection", "id" => id} ->
            {el,
             Map.put_new(activity_groups, "bank_selection_#{id}", %{
               group: ensure_number_is_string(group_id),
               survey: ensure_number_is_string(survey_id)
             })}

          _ ->
            {el, activity_groups}
        end
      end
    )
    |> then(fn {_, result} -> result end)
  end

  @doc """
  Finds all surveys in page content and lists all activities that belong to each survey.
  """
  def survey_activities(%{"model" => _model} = content) do
    map_reduce(
      content,
      %{},
      fn el, survey_activities, %TraversalContext{survey_id: survey_id} ->
        case {survey_id, el} do
          {survey_id, %{"type" => "activity-reference", "activity_id" => activity_id}}
          when not is_nil(survey_id) ->
            {el,
             Map.put(
               survey_activities,
               survey_id,
               [activity_id | Map.get(survey_activities, survey_id, [])]
             )}

          _ ->
            {el, survey_activities}
        end
      end
    )
    |> then(fn {_, result} -> result end)
  end

  def bibliography_rewire(%{"children" => _children} = item, acc, map_fn) do
    item_with_children(item, acc, map_fn, %TraversalContext{})
  end

  def visit_children(%{"children" => _children} = item, acc, map_fn) do
    item_with_children(item, acc, map_fn, %TraversalContext{})
  end

  def is_resource_group?(%{"type" => kind, "children" => _children})
      when kind in ["group", "survey", "alternatives", "alternative"],
      do: true

  def is_resource_group?(%{"type" => _} = _component), do: false
end
