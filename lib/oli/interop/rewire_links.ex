defmodule Oli.Ingest.RewireLinks do
  # Any internal hyperlinks have to be rewired to point to the new resource_id of the
  # page being linked to.  This function takes all pages and rewires
  # all links that it finds in their contents, only saving new revisions for those that
  # have a rewired link.
  def rewire_all_hyperlinks(page_map, project, lookup_map) do
    Map.values(page_map)
    |> Enum.map(fn revision ->
      rewire_hyperlinks(revision, lookup_map, project.slug)
    end)

    {:ok, page_map}
  end

  defp rewire_hyperlinks(revision, page_map, course) do
    link_builder = fn id ->
      case Map.get(page_map, id) do
        nil -> "/course/link/#{course}"
        %{slug: slug} -> "/course/link/#{slug}"
      end
    end

    case rewire(revision.content, link_builder, page_map) do
      {true, content} ->
        Oli.Resources.update_revision(revision, %{content: content})

      {false, _} ->
        {:ok, revision}
    end
  end

  defp rewire(items, link_builder, page_map) when is_list(items) do
    results = Enum.map(items, fn i -> rewire(i, link_builder, page_map) end)

    children = Enum.map(results, fn {_, c} -> c end)

    changed =
      Enum.map(results, fn {changed, _} -> changed end) |> Enum.any?(fn c -> c == true end)

    {changed, children}
  end

  defp rewire(%{"type" => "a", "idref" => idref, "children" => children}, link_builder, _page_map) do
    {true, %{"type" => "a", "children" => children, "href" => link_builder.(idref)}}
  end

  defp rewire(%{"type" => "page_link", "idref" => idref} = other, _link_builder, page_map) do
    {true, Map.put(other, "idref", Map.get(page_map, idref).resource_id)}
  end

  defp rewire(%{"model" => model} = item, link_builder, page_map) do
    case rewire(model, link_builder, page_map) do
      {true, model} -> {true, Map.put(item, "model", model)}
      {false, _} -> {false, item}
    end
  end

  defp rewire(%{"stem" => stem} = item, link_builder, page_map) do
    case rewire(stem, link_builder, page_map) do
      {true, stem} -> {true, Map.put(item, "stem", stem)}
      {false, _} -> {false, item}
    end
  end

  defp rewire(%{"content" => content} = item, link_builder, page_map) do
    case rewire(content, link_builder, page_map) do
      {true, content} -> {true, Map.put(item, "content", content)}
      {false, _} -> {false, item}
    end
  end

  defp rewire(%{"children" => children} = item, link_builder, page_map) do
    results = Enum.map(children, fn i -> rewire(i, link_builder, page_map) end)

    children = Enum.map(results, fn {_, c} -> c end)

    changed =
      Enum.map(results, fn {changed, _} -> changed end) |> Enum.any?(fn c -> c == true end)

    {changed, Map.put(item, "children", children)}
  end

  defp rewire(item, _, _) do
    {false, item}
  end
end
