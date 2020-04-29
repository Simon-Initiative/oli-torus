defmodule Oli.Rendering.Activity.Html do
  alias Oli.Rendering.Context

  @behaviour Oli.Rendering.Activity

  def activity(%Context{activity_map: activity_map}, %{"activitySlug" => activity_slug, "purpose" => purpose}) do
    activity_summary = activity_map[activity_slug]
    tag = activity_summary.delivery_element
    model_json = activity_summary.model_json
    activity_html = ["<#{tag} model=\"#{model_json}\"></#{tag}>\n"]

    case purpose do
      "None" ->
        activity_html
      _ ->
        ["<h4>", purpose, "</h4>", activity_html]
    end
  end

end
