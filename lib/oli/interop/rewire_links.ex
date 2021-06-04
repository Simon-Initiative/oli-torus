defmodule Oli.Ingest.RewireLinks do
  alias Oli.Publishing.ChangeTracker

  # Any internal hyperlinks have to be rewired to point to the new resource_id of the
  # page being linked to.  This function takes all pages and rewires
  # all links that it finds in their contents, only saving new revisions for those that
  # have a rewired link.
  def rewire_all_hyperlinks(page_map, project) do
    Map.values(page_map)
    |> Enum.map(fn revision ->
      rewire_hyperlinks(revision, page_map, project.slug)
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

    case rewire(revision.content, link_builder) do
      {true, content} ->
        ChangeTracker.track_revision(course, revision, %{content: content})

      {false, _} ->
        {:ok, revision}
    end
  end

  defp rewire(items, link_builder) when is_list(items) do
    results = Enum.map(items, fn i -> rewire(i, link_builder) end)

    children = Enum.map(results, fn {_, c} -> c end)

    changed =
      Enum.map(results, fn {changed, _} -> changed end) |> Enum.any?(fn c -> c == true end)

    {changed, children}
  end

  defp rewire(%{"type" => "a", "idref" => idref, "children" => children}, link_builder) do
    {true, %{"type" => "a", "children" => children, "href" => link_builder.(idref)}}
  end

  defp rewire(%{"model" => model} = item, link_builder) do
    case rewire(model, link_builder) do
      {true, model} -> {true, Map.put(item, "model", model)}
      {false, _} -> {false, item}
    end
  end

  defp rewire(%{"children" => children} = item, link_builder) do
    results = Enum.map(children, fn i -> rewire(i, link_builder) end)

    children = Enum.map(results, fn {_, c} -> c end)

    changed =
      Enum.map(results, fn {changed, _} -> changed end) |> Enum.any?(fn c -> c == true end)

    {changed, Map.put(item, "children", children)}
  end

  defp rewire(item, _) do
    {false, item}
  end
end
