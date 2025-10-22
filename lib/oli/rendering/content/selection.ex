defmodule Oli.Rendering.Content.Selection do
  def render(
        %Oli.Rendering.Context{
          section_slug: section_slug,
          revision_slug: revision_slug,
          activity_types_map: activity_types_map
        } = context,
        %{"logic" => logic, "count" => count, "id" => id} = selection,
        include_link?
      ) do
    titles = titles_from_selection(section_slug, selection)
    url = "/sections/#{section_slug}/preview/page/#{revision_slug}/selection/#{id}"

    count_desc =
      case count do
        1 -> "1 activity"
        _ -> "#{count} activities"
      end

    [
      "<div class=\"jumbotron selection\">",
      "<h2 class=\"display-6\">Activity Bank Selection</h2>",
      "<p class=\"lead\">The following activity bank selection will select ",
      "<span class=\"badge badge-pill badge-primary\">#{count_desc}</span> randomly according to the following constraints:",
      "</p>",
      "<hr class=\"my-4\">",
      [render_html(logic, titles, activity_types_map)],
      if include_link? do
        [
          "<p class=\"lead my-3\">",
          "<a class=\"btn btn-primary\" href=\"#{url}\" target=\"_blank\">Preview activities</a>",
          # Check if we're in instructor preview mode and have page_id
          if context.mode == :instructor_preview and context.page_id do
            review_url =
              "/sections/#{section_slug}/instructor_dashboard/review_activities/#{context.page_id}/#{id}"

            [
              " ",
              "<a class=\"btn btn-secondary\" href=\"#{review_url}\" target=\"_blank\">Review Activities</a>"
            ]
          else
            ""
          end,
          "</p>"
        ]
      else
        ""
      end,
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
        # This section_slug really is the project slug
        Oli.Publishing.AuthoringResolver.from_resource_id(section_slug, ids)
        |> Enum.filter(fn r -> !is_nil(r) end)
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

  defp activity_names(id, activity_types_map) do
    unless Map.equal?(activity_types_map, %{}),
      do: "<span class=\"activity-name\">#{Map.get(activity_types_map, id).title}</span>"
  end

  defp titles(ids, title_map, class) when is_list(ids) do
    Enum.map(ids, fn id -> titles(id, title_map, class) end)
    |> Enum.join(" ")
  end

  defp titles(id, title_map, class) do
    unless Map.equal?(title_map, %{}),
      do: "<span class=\"#{class}\">#{Map.get(title_map, id)}</span>"
  end
end
