defmodule Oli.Resources.PageContent do

  @doc"""
  Modelled after `Enum.map_reduce`, this invokes the given function to each content element in a page content tree.

  Returns a tuple where the first element is the mapped page content tree
  and the second one is the final accumulator.

  The function, map_fn, receives two arguments: the first one is the element, and the second one is the accumulator.
  map_fn must return a tuple with two elements in the form of {mapped content element, accumulator}.
  """
  def map_reduce(%{"model" => model} = content, acc, map_fn) do

    {items, acc} = Enum.reduce(model, {[], acc}, fn item, {items, acc} ->
      {item, acc} = map_reduce(item, acc, map_fn)
      {items ++ [item], acc}
    end)

    {Map.put(content, "model", items), acc}
  end

  def map_reduce(%{"type" => "content"} = content, acc, map_fn) do
    map_fn.(content, acc)
  end

  def map_reduce(%{"children" => children} = item, acc, map_fn) do

    {children, acc} = Enum.reduce(children, {[], acc}, fn item, {items, acc} ->
      {item, acc} = map_reduce(item, acc, map_fn)
      {items ++ [item], acc}
    end)

    Map.put(item, "children", children)
    |> map_fn.(acc)
  end

  def map_reduce(item, acc, map_fn) do
    map_fn.(item, acc)
  end

  @doc"""
  Flattens and filters the page content elements into a list. Implementated as a
  convenience function, over top of map_reduce.
  """
  def flat_filter(content, filter_fn) do
    {_, filtered} = map_reduce(content, [], fn e, filtered ->
      if filter_fn.(e) do
        {e, filtered ++ [e]}
      else
        {e, filtered}
      end
    end)

    filtered
  end

  @doc"""
  Maps the content elements of page content, preserving the as-is structure. Implementated as a
  convenience function, over top of map_reduce.
  """
  def map(content, map_fn) do
    {mapped, _} = map_reduce(content, 0, fn e, acc ->
      {map_fn.(e), 0}
    end)

    mapped
  end


end
