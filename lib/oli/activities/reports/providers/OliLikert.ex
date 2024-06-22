defmodule Oli.Activities.Reports.Providers.OliLikert do
  @behaviour Oli.Activities.Reports.Renderer

  alias Oli.Delivery.Attempts.Core
  alias Oli.Publishing.DeliveryResolver

  @impl Oli.Activities.Reports.Renderer
  def render(
        %Oli.Rendering.Context{enrollment: enrollment} =
          context,
        %{"activityId" => activity_id} = _element
      ) do
    {:safe, likert_report} =
      OliWeb.Common.React.component(context, "Components.LikerReportRenderer", %{
        sectionId: enrollment.section_id,
        activityId: activity_id
      })

    {:ok, [likert_report]}
  end

  @impl Oli.Activities.Reports.Renderer
  def report_data(section_id, user_id, activity_id) do
    %{data: data} = process_attempt_data(section_id, user_id, activity_id)

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

    parent = determine_parent_slug(section_id, activity_id)

    %{
      type: "success",
      spec: spec_from_json(data),
      prompts: prompts,
      parent: parent
    }
  end

  defp process_attempt_data(section_id, user_id, activity_id) do
    activity_attempt =
      Core.get_latest_activity_attempt(section_id, user_id, activity_id)
      |> Oli.Repo.preload(:part_attempts)

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

          {:ok, choice} = Enum.at(choices, r - 1) |> JSONPointer.get("/content/0/children/0/text")

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

    %{data: Map.get(info, :values)}
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

  defp spec_from_json(data) do
    encoded = Jason.encode!(data)

    VegaLite.from_json("""
    {
      "width": 500,
      "height": #{30 * length(data)},
      "description": "A chart with embedded data.",
      "data": {
        "values": #{encoded}
      },
      "mark": {
        "type": "circle",
        "size": "90"
      },
      "encoding": {
          "y": {
              "field": "prompt",
              "type": "ordinal",
              "sort": {
                  "field": "index",
                  "order": "ascending"
              },
              "axis": {
                  "labelAngle": 0,
                  "grid": true
              },
              "title": "Prompts"
          },
          "x": {
              "field": "response",
              "type": "quantitative",
              "title": "Likert Scale",
              "axis": {"tickMinStep": 1}
          },
          "color": {
              "field": "color",
              "type": "nominal",
              "scale": null
          }
      },
      "layer": [
        {
          "mark": {"type": "text", "x": 255, "align": "left", "size": "14"},
          "encoding": {
            "text": {"field": "choice"}
          }
        }
      ]
    }
    """)
    |> VegaLite.to_spec()
  end

  defp determine_parent_slug(section_id, activity_id) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    pub_ids = DeliveryResolver.section_publication_ids(section.slug) |> Oli.Repo.all()

    case Map.get(Oli.Publishing.determine_parent_pages([activity_id], pub_ids), activity_id) do
      %{id: _id, slug: slug} ->
        parent_revision = DeliveryResolver.from_revision_slug(section.slug, slug)

        title =
          if is_nil(parent_revision) do
            "Activity"
          else
            parent_revision.title
          end

        %{title: title, slug: slug}

      _ ->
        %{title: "Activity"}
    end
  end
end
