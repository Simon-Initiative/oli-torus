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

    try do
      case rewire(revision.content, link_builder, page_map) do
        {true, content} ->
          Oli.Resources.update_revision(revision, %{content: content})

        {false, _} ->
          {:ok, revision}
      end
    rescue
      _ in KeyError -> {:ok, revision}
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

  # When we encounter a "stem" object, we know we are processing an activity.  Therefore,
  # we continue to process (if they exist) the "authoring" and "choices" objects. All during
  # this processing, we track whether or not we are changing anything. We return that result
  # as the first element of the tuple, with the potentially updated content as the second.
  # This allows then the caller to know whether or not to save a new revision.
  defp rewire(%{"stem" => stem} = item, link_builder, page_map) do
    {stem_result, item} = case rewire(stem, link_builder, page_map) do
      {true, stem} -> {true, Map.put(item, "stem", stem)}
      {false, _} -> {false, item}
    end

    {authoring_result, item} = case Map.get(item, "authoring") do
      nil -> {false, item}
      authoring ->
        {result, parts} = case Map.get(authoring, "parts") do
          nil -> {false, item}
          parts ->
            {results, parts} = Enum.map(parts, fn part ->

              {exp_result, part} = case Map.get(part, "explanation") do
                nil -> {false, part}
                exp ->
                  {exp_result, exp} = rewire(exp, link_builder, page_map)
                  {exp_result, Map.put(part, "explanation", exp)}
              end

              {hint_result, part} = case Map.get(part, "hints") do
                nil -> {false, part}
                hints ->
                  {hint_result, hints} = rewire(hints, link_builder, page_map)
                  {hint_result, Map.put(part, "hints", hints)}
              end

              {resp_result, part} = case Map.get(part, "responses") do
                nil -> {false, part}
                responses ->
                  {results, responses} = Enum.map(responses, fn r ->
                    case Map.get(r, "feedback") do
                      nil -> {false, r}
                      feedback ->
                        {result, feedback} = rewire(feedback, link_builder, page_map)
                        {result, Map.put(r, "feedback", feedback)}
                    end
                  end)
                  |> Enum.unzip

                  {Enum.any?(results), Map.put(part, "responses", responses)}
              end

              {exp_result || hint_result || resp_result, part}

            end)
            |> Enum.unzip

            {Enum.any?(results), parts}
        end
        authoring = Map.put(authoring, "parts", parts)
        {result, Map.put(item, "authoring", authoring)}
    end

    {choices_result, item} = case Map.get(item, "choices") do
      nil -> {false, item}
      choices ->
        {r, choices} = rewire(choices, link_builder, page_map)
        {r, Map.put(item, "choices", choices)}
    end

    {stem_result || authoring_result || choices_result, item}
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
