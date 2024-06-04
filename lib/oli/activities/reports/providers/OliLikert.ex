defmodule Oli.Activities.Reports.Providers.OliLikert do
  @behaviour Oli.Activities.Reports.Renderer

  alias Oli.Delivery.Attempts.Core

  @impl Oli.Activities.Reports.Renderer
  def render(
        %Oli.Rendering.Context{enrollment: enrollment, user: user} = context,
        %{"activityId" => activity_id} = _element
      ) do
    data = report_data(enrollment.section_id, user.id, activity_id)
    data_url = "/api/v1/activity/report/#{enrollment.section_id}/#{activity_id}"

    prompts = [~s|<div>
    <ul>|, prompts_from_items(data), "</ul></div>"]

    {:ok, [visualization(context, data, data_url), prompts]}
  end

  @impl Oli.Activities.Reports.Renderer
  def report_data(section_id, user_id, activity_id) do
    activity_attempt =
      Core.get_latest_activity_attempt(section_id, user_id, activity_id)
      |> Oli.Repo.preload(:part_attempts)

    part_attempts_by_id =
      Enum.reduce(activity_attempt.part_attempts, %{}, fn a, c -> Map.put(c, a.part_id, a) end)

    Map.get(activity_attempt.revision.content, "items")
    |> Enum.with_index()
    |> Enum.reduce([], fn {a, idx}, c ->
      {:ok, p} = JSONPointer.get(a, "/content/0/children/0/text")
      r = Map.get(part_attempts_by_id, Map.get(a, "id"))
      {:ok, r} = JSONPointer.get(r.response, "/input")

      value = %{
        prompt_long: "P#{idx + 1}: #{p}",
        prompt: "P#{idx + 1}",
        response: r,
        color: color_matcher(Map.get(a, "group")),
        index: idx
      }

      c ++ [value]
    end)
  end

  defp prompts_from_items(data) do
    Enum.reduce(data, [], fn a, c ->
      prompt = ~s|<li style="color:#{Map.get(a, :color)}">#{Map.get(a, :prompt_long)}</li>|
      [c | prompt]
    end)
  end

  defp color_matcher(str) when is_binary(str) do
    case String.downcase(str) do
      "shallow" -> "red"
      "deep" -> "green"
      _ -> "blue"
    end
  end

  defp color_matcher(_), do: "blue"

  defp visualization(%Oli.Rendering.Context{} = context, _data, data_url) do
    # encoded = Jason.encode!(data)

    spec =
      VegaLite.from_json("""
      {
        "width": 500,
        "height": 300,
        "description": "A simple bar chart with embedded data.",
        "data": {
            "url": "#{data_url}"
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
                            "labelAngle": 0
                        }
                    },
                    "y": {
                        "field": "response",
                        "type": "quantitative"
                    },
                    "color": {
                        "field": "color",
                        "type": "nominal",
                        "scale": null
                    }
                }
            }
        ]
      }
      """)
      |> VegaLite.to_spec()

    {:safe, attempt_selector} =
      OliWeb.Common.React.component(context, "Components.VegaLiteRenderer", %{spec: spec})

    [attempt_selector]
  end
end
