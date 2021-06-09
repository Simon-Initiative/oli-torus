defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for Oli activity rendering
  """
  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @behaviour Oli.Rendering.Activity

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          preview: preview,
          review_mode: review_mode,
          user: user
        } = context,
        %{"activity_id" => activity_id, "purpose" => purpose} = activity
      ) do
    activity_summary = activity_map[activity_id]

    case activity_summary do
      nil ->
        error_id = Utils.random_string(8)

        error_msg =
          "ActivitySummary with id #{activity_id} missing from activity_map: #{
            Kernel.inspect({activity, activity_map})
          }"

        if render_opts.log_errors,
          do: Logger.error("Render Error ##{error_id} #{error_msg}"),
          else: nil

        if render_opts.render_errors do
          error(context, activity, {:activity_missing, error_id, error_msg})
        else
          []
        end

      _ ->
        tag = activity_summary.delivery_element
        state = activity_summary.state
        graded = activity_summary.graded
        model_json = activity_summary.model
        section_slug = context.section_slug

        activity_html = [
          "<#{tag} class=\"activity-container\" graded=\"#{graded}\" state=\"#{state}\" model=\"#{
            model_json
          }\" preview=\"#{preview}\" user_id=\"#{user.id}\" review=\"#{review_mode}\" section_slug=\"#{
            section_slug
          }\"></#{tag}>\n"
        ]

        case purpose do
          "none" ->
            activity_html

          _ ->
            [
              "<h4 class=\"activity-purpose ",
              Oli.Utils.Slug.slugify(purpose),
              "\">",
              Oli.Utils.Purposes.label_for(purpose),
              "</h4>",
              activity_html
            ]
        end
    end
  end

  def error(%Context{}, _activity, error) do
    case error do
      {:invalid, error_id, _error_msg} ->
        [
          "<div class=\"activity invalid alert alert-danger\">Activity error. Please contact support with issue <strong>##{
            error_id
          }</strong></div>\n"
        ]

      {_, error_id, _error_msg} ->
        [
          "<div class=\"activity error alert alert-danger\">An error occurred and this activity could not be shown. Please contact support with issue <strong>##{
            error_id
          }</strong></div>\n"
        ]
    end
  end
end
