defmodule Oli.Ingest.RewireLinks do
  require Logger

  @link_container_keys ~w[
    children
    content
    model
    stem
    choices
    authoring
    parts
    responses
    feedback
    hints
    custom
    nodes
    partsLayout
    caption
    pronunciation
    translations
  ]

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
    resource_id_lookup = build_resource_id_lookup(page_map)

    link_builder = fn id ->
      case lookup_revision(page_map, resource_id_lookup, id) do
        nil -> "/course/link/#{course}"
        %{slug: slug} -> "/course/link/#{slug}"
      end
    end

    try do
      case rewire(revision.content, link_builder, page_map, resource_id_lookup) do
        {true, content} ->
          Oli.Resources.update_revision(revision, %{content: content})

        {false, _} ->
          {:ok, revision}
      end
    rescue
      _ in KeyError -> {:ok, revision}
    end
  end

  @doc false
  def lookup_revision(page_map, resource_id_lookup, id) do
    Map.get(page_map, id) ||
      Map.get(page_map, normalize_key(id)) ||
      Map.get(resource_id_lookup, id) ||
      Map.get(resource_id_lookup, normalize_key(id))
  end

  defp build_resource_id_lookup(page_map) do
    page_map
    |> Map.values()
    |> Enum.reduce(%{}, fn
      %{resource_id: resource_id} = revision, acc ->
        acc
        |> Map.put(resource_id, revision)
        |> Map.put(Integer.to_string(resource_id), revision)

      _, acc ->
        acc
    end)
  end

  defp normalize_key(key) when is_integer(key), do: Integer.to_string(key)

  defp normalize_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {parsed, ""} -> parsed
      _ -> key
    end
  end

  defp normalize_key(key), do: key

  def rewire(items, link_builder, page_map) when is_list(items) do
    resource_id_lookup = build_resource_id_lookup(page_map)
    rewire(items, link_builder, page_map, resource_id_lookup)
  end

  def rewire(item, link_builder, page_map) when is_map(item) do
    resource_id_lookup = build_resource_id_lookup(page_map)
    rewire(item, link_builder, page_map, resource_id_lookup)
  end

  def rewire(value, _link_builder, _page_map)
      when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
      do: {false, value}

  def rewire(value, _link_builder, _page_map), do: {false, value}

  defp rewire(items, link_builder, page_map, resource_id_lookup) when is_list(items) do
    {rewritten, changed?} =
      Enum.reduce(items, {[], false}, fn item, {acc, changed?} ->
        if maybe_link_payload?(item) do
          {item_changed?, rewired_item} = rewire(item, link_builder, page_map, resource_id_lookup)
          {[rewired_item | acc], changed? || item_changed?}
        else
          {[item | acc], changed?}
        end
      end)

    if changed? do
      {true, Enum.reverse(rewritten)}
    else
      {false, items}
    end
  end

  defp rewire(
         %{"type" => "a", "idref" => idref, "children" => children} = link,
         link_builder,
         _page_map,
         _resource_id_lookup
       ) do
    target = Map.get(link, "target")
    anchor = Map.get(link, "anchor")

    putIfNotNil = fn map, key, value ->
      if is_nil(value) do
        map
      else
        Map.put(map, key, value)
      end
    end

    {true,
     %{"type" => "a", "children" => children, "href" => link_builder.(idref)}
     |> putIfNotNil.("target", target)
     |> putIfNotNil.("anchor", anchor)}
  end

  defp rewire(
         %{"tag" => "a", "idref" => idref} = link,
         link_builder,
         _page_map,
         _resource_id_lookup
       ) do
    {true, link |> Map.put("href", link_builder.(idref)) |> Map.delete("idref")}
  end

  defp rewire(
         %{"type" => "page_link", "idref" => idref} = other,
         _link_builder,
         page_map,
         resource_id_lookup
       ) do
    case lookup_revision(page_map, resource_id_lookup, idref) do
      %{resource_id: resource_id} ->
        {true, Map.put(other, "idref", resource_id)}

      nil ->
        Logger.warning("Skipping page_link rewiring, missing idref mapping for #{inspect(idref)}")
        {false, other}
    end
  end

  defp rewire(
         %{"type" => "janus-capi-iframe"} = part,
         link_builder,
         page_map,
         resource_id_lookup
       ) do
    {part_changed?, rewritten_part} =
      rewire_iframe_dynamic_link(part, link_builder, page_map, resource_id_lookup)

    {custom_changed?, rewritten_custom} =
      case Map.get(rewritten_part, "custom") do
        %{} = custom ->
          rewire_iframe_dynamic_link(custom, link_builder, page_map, resource_id_lookup)

        _ ->
          {false, nil}
      end

    if custom_changed? do
      {true, Map.put(rewritten_part, "custom", rewritten_custom)}
    else
      {part_changed?, rewritten_part}
    end
  end

  defp rewire(item, link_builder, page_map, resource_id_lookup) when is_map(item) do
    if maybe_link_payload?(item) do
      Enum.reduce(item, {false, item}, fn {key, value}, {changed?, acc} ->
        case value do
          value when is_list(value) or is_map(value) ->
            if maybe_link_payload?(value) do
              {value_changed?, rewired_value} =
                rewire(value, link_builder, page_map, resource_id_lookup)

              if value_changed? do
                {true, Map.put(acc, key, rewired_value)}
              else
                {changed?, acc}
              end
            else
              {changed?, acc}
            end

          _ ->
            {changed?, acc}
        end
      end)
    else
      {false, item}
    end
  end

  defp maybe_link_payload?(%{} = item) do
    direct_link_node? =
      Map.has_key?(item, "idref") or
        Map.has_key?(item, "resource_id") or
        Map.get(item, "type") in ["a", "page_link"] or
        Map.get(item, "tag") == "a"

    direct_link_node? or
      Enum.any?(item, fn {key, _value} -> key in @link_container_keys end)
  end

  defp maybe_link_payload?(items) when is_list(items) do
    Enum.any?(items, &maybe_link_payload?/1)
  end

  defp maybe_link_payload?(_), do: false

  defp rewire_iframe_dynamic_link(part, link_builder, page_map, resource_id_lookup) do
    if internal_iframe_source?(part) do
      case Map.get(part, "idref") || Map.get(part, "resource_id") do
        nil ->
          {false, part}

        idref ->
          case lookup_revision(page_map, resource_id_lookup, idref) do
            %{resource_id: resource_id, slug: slug} ->
              rewritten =
                part
                |> Map.put("idref", resource_id)
                |> Map.put("resource_id", resource_id)
                |> Map.put("sourceType", "page")
                |> Map.put("linkType", "page")
                |> Map.put("sourcePageSlug", slug)
                |> Map.put("src", link_builder.(resource_id))
                |> maybe_rewrite_iframe_source(resource_id, slug)

              {rewritten != part, rewritten}

            nil ->
              Logger.warning(
                "Skipping adaptive iframe rewiring, missing idref mapping for #{inspect(idref)}"
              )

              {false, part}
          end
      end
    else
      {false, part}
    end
  end

  defp maybe_rewrite_iframe_source(%{"source" => source} = part, resource_id, slug)
       when is_binary(source) do
    case Jason.decode(source) do
      {:ok, decoded} when is_map(decoded) ->
        updated =
          decoded
          |> Map.put("mode", "page")
          |> Map.put("pageId", resource_id)
          |> Map.put("pageSlug", slug)
          |> Map.put("url", "")

        Map.put(part, "source", Jason.encode!(updated))

      _ ->
        part
    end
  end

  defp maybe_rewrite_iframe_source(%{"source" => source} = part, resource_id, slug)
       when is_map(source) do
    updated =
      source
      |> Map.put("mode", "page")
      |> Map.put("pageId", resource_id)
      |> Map.put("pageSlug", slug)
      |> Map.put("url", "")

    Map.put(part, "source", updated)
  end

  defp maybe_rewrite_iframe_source(part, _resource_id, _slug), do: part

  defp internal_iframe_source?(%{"sourceType" => "url"}), do: false

  defp internal_iframe_source?(%{} = part) do
    src = Map.get(part, "src")
    source_type = Map.get(part, "sourceType")
    link_type = Map.get(part, "linkType")
    idref = Map.get(part, "idref") || Map.get(part, "resource_id")

    source_type == "page" or
      link_type == "page" or
      internal_course_link?(src) or
      not is_nil(idref)
  end

  defp internal_iframe_source?(_), do: false

  defp internal_course_link?(value) when is_binary(value),
    do: String.starts_with?(value, "/course/link/")

  defp internal_course_link?(_), do: false
end
