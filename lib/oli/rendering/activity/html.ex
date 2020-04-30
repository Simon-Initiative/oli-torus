defmodule Oli.Rendering.Activity.Html do
  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @behaviour Oli.Rendering.Activity

  def activity(%Context{activity_map: activity_map, render_opts: render_opts} = context, %{"activitySlug" => activity_slug, "purpose" => purpose} = activity) do
    activity_summary = activity_map[activity_slug]

    case activity_summary do
      nil ->
        error_id = Utils.random_string(8)
        error_msg = "Activity summary with slug #{activity_slug} missing from activity_map: #{Kernel.inspect({activity, activity_map})}"
        if render_opts.log_errors, do: Logger.error("Render Error ##{error_id} #{error_msg}"), else: nil

        if render_opts.render_errors do
          error(context, activity, {:activity_missing, error_id, error_msg})
        else
          []
        end
      _ ->
        tag = activity_summary.delivery_element
        model_json = activity_summary.model_json
        activity_html = ["<#{tag} class=\"activity\" model=\"#{model_json}\"></#{tag}>\n"]

        case purpose do
          "None" ->
            activity_html
          _ ->
            ["<h4 class=\"activity-purpose\">", purpose, "</h4>", activity_html]
        end
    end
  end

  def error(%Context{}, _activity, error) do
    case error do
      {:invalid, _error_id, _error_msg} ->
        ["<div class=\"activity invalid\">Activity is invalid</div>\n"]
      {_, error_id, _error_msg} ->
        ["<div class=\"activity error\">This activity could not be rendered. Please contact support with issue ##{error_id}</div>\n"]
    end
  end

end
