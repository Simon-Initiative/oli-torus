defmodule Oli.Rendering.Content.Selection do
  def render(
        %Oli.Rendering.Context{
          section_slug: section_slug,
          revision_slug: revision_slug,
          activity_types_map: activity_types_map
        },
        %{"logic" => logic, "count" => count, "id" => id} = selection
      ) do
    titles = titles_from_selection(section_slug, selection)
    url = "/sections/#{section_slug}/preview/page/#{revision_slug}/selection/#{id}"

    prefix =
      case count do
        1 -> "<p>Selecting 1 activity from:</p>"
        _ -> "<p>Selecting #{count} activities from:</p>"
      end

    [
      "<div class=\"selection\"><div class=\"title\">Activity Bank Selection</div>",
      [prefix, render_html(logic, titles, activity_types_map)],
      "<a href=\"#{url}\">Preview all possible activities for this selection</a>",
      "</div>"
    ]
  end

  defp render_html(items, titles, activity_types_map) when is_list(items) do
    Enum.map(items, fn item -> render_html(item, titles, activity_types_map) end)
  end

  defp render_html(%{"conditions" => nil}, _, _) do
    ["<div>All activities</div>"]
  end

  defp render_html(%{"conditions" => conditions}, titles, activity_types_map) do
    ["<ul>", render_html(conditions, titles, activity_types_map), "</ul>\n"]
  end

  defp render_html(%{"children" => children, "operator" => operator}, titles, activity_types_map) do
    [
      "<li>#{operator} of the following:<ul>",
      render_html(children, titles, activity_types_map),
      "</ul></li>\n"
    ]
  end

  defp render_html(
         %{"fact" => fact, "operator" => operator, "value" => value},
         title_map,
         activity_types_map
       ) do
    case fact do
      "text" ->
        [
          "<li>Activity <span class=\"operator\">#{desc(operator)}</strong> &quot;#{value}&quot;</li>"
        ]

      "type" ->
        [
          "<li>Type of activity <span class=\"operator\">#{desc(operator)}</span> #{activity_names(value, activity_types_map)}</li>"
        ]

      "objectives" ->
        [
          "<li>Learning objectives <span class=\"operator\">#{desc(operator)}</span> #{titles(value, title_map, "objective")}</li>"
        ]

      "tags" ->
        [
          "<li>Tags <span class=\"operator\">#{desc(operator)}</span> #{titles(value, title_map, "tag")}</li>"
        ]
    end
  end

  defp titles_from_selection(section_slug, %{
         "logic" => logic
       }) do
    case resource_ids(logic) do
      [] ->
        %{}

      ids ->
        Oli.Publishing.DeliveryResolver.from_resource_id(section_slug, ids)
        |> Enum.reduce(%{}, fn rev, m -> Map.put(m, rev.resource_id, rev.title) end)
    end
  end

  defp resource_ids(%{"conditions" => nil}) do
    []
  end

  defp resource_ids(%{"conditions" => conditions}) do
    resource_ids(conditions, [])
  end

  defp resource_ids(%{"children" => children}, all) do
    Enum.reduce(children, all, fn c, ids -> resource_ids(c, ids) end)
  end

  defp resource_ids(%{"value" => value, "fact" => fact}, all) do
    case fact do
      "tags" -> value ++ all
      "objectives" -> value ++ all
      _ -> all
    end
  end

  defp desc("contains"), do: "contains"
  defp desc("does_not_contain"), do: "does not contain"
  defp desc("equals"), do: "equals"
  defp desc("does_not_equal"), do: "does not equal"

  defp activity_names(ids, activity_types_map) when is_list(ids) do
    Enum.map(ids, fn id -> activity_names(id, activity_types_map) end)
    |> Enum.join(" ")
  end

  defp activity_names(id, activity_types_map),
    do: "<span class=\"activity-name\">#{Map.get(activity_types_map, id).title}</span>"

  defp titles(ids, title_map, class) when is_list(ids) do
    Enum.map(ids, fn id -> titles(id, title_map, class) end)
    |> Enum.join(" ")
  end

  defp titles(id, title_map, class),
    do: "<span class=\"#{class}\">#{Map.get(title_map, id)}</span>"
end
