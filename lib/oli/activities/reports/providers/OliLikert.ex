defmodule Oli.Activities.Reports.Providers.OliLikert do
  @behaviour Oli.Activities.Reports.Renderer

  alias Oli.Delivery.Attempts.Core
  alias Oli.Publishing.DeliveryResolver

  @impl Oli.Activities.Reports.Renderer
  def render(
        %Oli.Rendering.Context{enrollment: enrollment, section_slug: section_slug} =
          context,
        %{"activityId" => activity_id} = _element
      ) do
    {:safe, likert_report} =
      OliWeb.Common.React.component(context, "Components.LikertReportRenderer", %{
        sectionId: enrollment.section_id,
        activityId: activity_id,
        sectionSlug: section_slug
      })

    {:ok, [likert_report]}
  end

  @impl Oli.Activities.Reports.Renderer
  def report_data(section_id, user_id, activity_id) do
    parent = determine_parent_slug(section_id, activity_id)

    case process_attempt_data(section_id, user_id, activity_id) do
      {:ok, data, scale} ->
        by_group =
          Enum.reduce(data, %{}, fn a, c ->
            group = Map.get(a, :group)
            glist = Map.get(c, group, [])
            Map.put(c, group, glist ++ [a])
          end)

        prompts =
          Enum.reduce(by_group, [], fn {k, v}, c ->
            h = if is_nil(k), do: "", else: k
            c ++ [~s|<div><h3>#{h}</h3><ul>|, prompts_from_items(v), "</ul></div>"]
          end)

        prompts =
          Phoenix.HTML.raw([~s|<div>|, prompts, "</div>"])
          |> Phoenix.HTML.safe_to_string()
          |> String.trim()

        %{
          type: "success",
          spec: spec_from_json(data, scale),
          prompts: prompts,
          parent: parent
        }

      {:error, message} ->
        %{
          type: "success",
          message: message,
          parent: parent
        }
    end
  end

  defp process_attempt_data(section_id, user_id, activity_id) do
    activity_attempt =
      Core.get_latest_activity_attempt(section_id, user_id, activity_id)
      |> Oli.Repo.preload(:part_attempts)

    if is_nil(activity_attempt) do
      {:error,
       "If you do not see your personalized report here, it means that you have not yet completed the activity linked to this report"}
    else
      part_attempts_by_id =
        Enum.reduce(activity_attempt.part_attempts, %{}, fn a, c -> Map.put(c, a.part_id, a) end)

      content =
        if is_nil(activity_attempt.transformed_model) do
          activity_attempt.revision.content
        else
          activity_attempt.transformed_model
        end

      ordinal =
        Map.get(content, "choices")
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {a, idx}, c ->
          val = idx + 1
          Map.put(c, Map.get(a, "id"), val)
        end)

      choices = Map.get(content, "choices")

      get_text = fn x ->
        case JSONPointer.get(x, "/content/0/children/0/text") do
          {:ok, pv} -> pv
          {:error, _} -> ""
        end
      end

      scale = %{
        max: Enum.count(choices),
        lo: Enum.at(choices, 0) |> get_text.(),
        hi: Enum.at(choices, Enum.count(choices) - 1) |> get_text.()
      }

      info =
        Map.get(content, "items")
        |> Enum.with_index()
        |> Enum.reduce(
          %{
            colors: Map.new(),
            values: [],
            color_list: [
              "red",
              "green",
              "purple",
              "brown",
              "maroon",
              "fuchsia",
              "olive",
              "teal",
              "navy"
            ]
          },
          fn {a, idx}, c ->
            p =
              case JSONPointer.get(a, "/content/0/children/0/text") do
                {:ok, pv} -> pv
                {:error, _} -> ""
              end

            r = Map.get(part_attempts_by_id, Map.get(a, "id"))

            r =
              case JSONPointer.get(r.response, "/input") do
                {:ok, response_value} -> Map.get(ordinal, response_value)
                {:error, _} -> ""
              end

            group = Map.get(a, "group")

            {:ok, choice} =
              if is_integer(r),
                do: Enum.at(choices, r - 1) |> JSONPointer.get("/content/0/children/0/text"),
                else: {:ok, ""}

            {color, c} =
              case Map.get(Map.get(c, :colors), group) do
                nil ->
                  color_pick(c, group)

                col ->
                  {col, c}
              end

            value = %{
              prompt_long: "P#{idx + 1}: #{p}",
              prompt: "P#{idx + 1}",
              response: r,
              color: color,
              group: group,
              index: idx,
              choice: choice
            }

            values = Map.get(c, :values)
            Map.put(c, :values, values ++ [value])
          end
        )

      {:ok, Map.get(info, :values), scale}
    end
  end

  defp prompts_from_items(data) do
    Enum.reduce(data, [], fn a, c ->
      prompt = ~s|<li style="color:#{Map.get(a, :color)}">#{Map.get(a, :prompt_long)}</li>|
      [c | prompt]
    end)
  end

  defp color_pick(c, group) do
    colors = Map.get(c, :colors)
    color_list = Map.get(c, :color_list)
    index = :rand.uniform(length(color_list))
    col = Enum.at(color_list, index)
    color_list = List.delete_at(color_list, index)
    c = Map.put(c, :color_list, color_list)
    c = Map.put(c, :colors, Map.put(colors, group, col))
    {col, c}
  end

  defp build_sub_chart(group, data, scale) do

    scale_values = 1..scale.max |> Enum.join(",")
    width = max(50 * scale.max, 600)

    """
    {
      "width": #{width},
      "height": #{30 * length(data)},
      "description": "A chart with embedded data.",
      "data": {
        "name": "#{group}"
      },
      "title": "#{group}",
      "encoding": {
        "y": {
          "field": "prompt",
          "type": "nominal",
          "sort": null,
          "axis": {
            "domain": false,
            "offset": 50,
            "labelFontWeight": "bold",
            "ticks": false,
            "grid": true,
            "title": null,
            "labels": false
          }
        },
        "x": {
          "type": "quantitative",
          "scale": {"domain": [0, #{scale.max + 1}]},
          "axis": {"grid": false, "values": [#{scale_values}], "title": null}
        }
      },
      "view": {"stroke": null},
      "layer": [
        {
          "mark": {"type": "circle", "size": 100},
          "data": {"name": "#{group}"},
          "encoding": {
            "x": {"field": "response"},
            "color": {"value": "#6EB4FD"},
            "tooltip": {"field": "tooltip", "type": "nominal"}
          }
        },
        {
          "mark": {"type": "text", "x": -5, "align": "right"},
          "encoding": {
            "text": {"field": "lo"}
          }
        },
        {
          "mark": {"type": "text", "x": #{width}, "align": "left"},
          "encoding": {
            "text": {"field": "hi"}
          }
        }
      ]
    }
    """
  end

  defp spec_from_json(data, scale) do

    # change 'nil' group to "Results"
    data = Enum.map(data, fn x ->
      if is_nil(Map.get(x, :group)) do
        Map.put(x, :group, "Results")
      else
        x
      end
    end)

    # Set the tooltips
    data = Enum.map(data, fn d ->
      Map.put(d, :tooltip, "#{d.prompt_long}: #{d.choice}")
      |> Map.put(:lo, scale.lo)
      |> Map.put(:hi, scale.hi)
    end)

    # Group by group name
    distinct_groups = Enum.uniq(Enum.map(data, &Map.get(&1, :group)))
    values_by_group = Enum.group_by(data, &Map.get(&1, :group))

    subcharts = Enum.map(distinct_groups, fn group ->
      data = Map.get(values_by_group, group)
      build_sub_chart(group, data, scale)
    end)
    |> Enum.join(",")

    datasets = Enum.reduce(distinct_groups, %{}, fn group, c ->
      values = Map.get(values_by_group, group)
      Map.put(c, group, values)
    end)
    |> Jason.encode!()

    str_spec = """
    {
      "datasets": #{datasets},
      "vconcat": [#{subcharts}]
    }
    """

    VegaLite.from_json(str_spec)
    |> VegaLite.to_spec()
  end

  defp determine_parent_slug(section_id, activity_id) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    pub_ids = DeliveryResolver.section_publication_ids(section.slug) |> Oli.Repo.all()

    case Oli.Publishing.determine_parent_pages(activity_id, pub_ids) do
      %{"title" => title, "slug" => slug} ->
        %{title: title, slug: slug}

      _ ->
        %{title: "Activity"}
    end
  end
end
