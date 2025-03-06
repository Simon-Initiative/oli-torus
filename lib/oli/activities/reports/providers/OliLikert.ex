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
      {:ok, data} ->
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
          spec: spec_from_json(data),
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

      {:ok, Map.get(info, :values)}
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
    index = :rand.uniform(length(color_list) - 1)
    col = Enum.at(color_list, index)
    color_list = List.delete_at(color_list, index)
    c = Map.put(c, :color_list, color_list)
    c = Map.put(c, :colors, Map.put(colors, group, col))
    {col, c}
  end

  defp spec_from_json(data) do
    groups =
      data
      |> Enum.reduce([], fn a, c ->
        group = Map.get(a, :group)
        if Enum.member?(c, group), do: c, else: c ++ [group]
      end)
      |> Enum.join(" ---------- ")

    encoded = Jason.encode!(data)

    VegaLite.from_json("""
    {
      "width": 500,
      "height": 300,
      "description": "A chart with embedded data.",
      "data": {
          "values": #{encoded}
      },
      "layer": [
          {
              "mark": "bar",
              "encoding": {
                  "x": {
                      "field": "prompt",
                      "type": "ordinal",
                      "sort": {
                          "field": "index",
                          "order": "ascending"
                      },
                      "axis": {
                          "labelAngle": 0,
                          "titleFontSize": 18,
                          "titleAlign": "center"
                      },
                      "title": "<-- #{groups} -->"
                  },
                  "y": {
                      "field": "response",
                      "type": "quantitative",
                      "title": "Scale"
                  },
                  "color": {
                      "field": "color",
                      "type": "nominal",
                      "scale": null
                  }
              }
          },
         {
              "mark": "text",
              "encoding": {
                  "y": {
                      "field": "choice",
                      "type": "nominal",
                      "sort": "descending",
                      "title": "Choice",
                      "axis": { "orient": "right" }
                  }
              }
          }
      ],
      "resolve": {"scale": {"y": "independent"}}
    }
    """)
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
