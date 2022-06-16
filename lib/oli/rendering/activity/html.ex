defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Activity

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          mode: mode,
          user: user,
          bib_app_params: bib_app_params
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
       
    activity_summary = activity_map[activity_id]

    bib_params = Enum.reduce(bib_app_params, [], fn x, acc ->
      acc ++ [%{"id" => x.id, "ordinal" => x.ordinal, "slug" => x.slug, "title" => x.title}]
    end)

    {:ok, bib_params_json} = Jason.encode(bib_params)
    case activity_summary do
      nil ->
        {error_id, error_msg} =
          log_error(
            "ActivitySummary with id #{activity_id} missing from activity_map",
            {activity, activity_map}
          )

        if render_opts.render_errors do
          error(context, activity, {:activity_missing, error_id, error_msg})
        else
          []
        end

      _ ->
        tag =
          case mode do
            :instructor_preview -> activity_summary.authoring_element
            _ -> activity_summary.delivery_element
          end

        state = activity_summary.state
        graded = activity_summary.graded
        model_json = activity_summary.model
        section_slug = context.section_slug

        activity_html =
          case mode do
            :instructor_preview ->
              [
                "<#{tag} model=\"#{model_json}\" bib_params=\"#{Base.encode64(bib_params_json)}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>\n"
              ]

            _ ->
              [
                "<#{tag} class=\"activity-container\" bib_params=\"#{Base.encode64(bib_params_json)}\" graded=\"#{graded}\" state=\"#{state}\" model=\"#{model_json}\" mode=\"#{mode}\" user_id=\"#{user.id}\" section_slug=\"#{section_slug}\"></#{tag}>\n"
              ]
          end

        # purposes types directly on activities is deprecated but rendering is left here to support legacy content
        case activity["purpose"] do
          nil ->
            activity_html

          "none" ->
            activity_html

          purpose ->
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

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
