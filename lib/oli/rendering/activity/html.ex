defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils
  import Oli.Rendering.Activity.Common

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Rendering.Activity.ActivitySummary

  @behaviour Oli.Rendering.Activity

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          mode: mode,
          user: user,
          group_id: group_id,
          survey_id: survey_id,
          bib_app_params: bib_app_params
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
    activity_summary = activity_map[activity_id]

    bib_params =
      Enum.reduce(bib_app_params, [], fn x, acc ->
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

      %ActivitySummary{
        authoring_element: authoring_element,
        delivery_element: delivery_element,
        state: state,
        graded: graded,
        model: model
      } ->
        tag =
          case mode do
            :instructor_preview -> authoring_element
            _ -> delivery_element
          end

        section_slug = context.section_slug

        activity_html =
          case mode do
            :instructor_preview ->
              [
                ~s|<#{tag} model="#{model}" editmode="false" projectSlug="#{section_slug}" bib_params="#{Base.encode64(bib_params_json)}" #{maybe_group_id(group_id)}#{maybe_survey_id(survey_id)}></#{tag}>\n|
              ]

            _ ->
              [
                ~s|<#{tag} class="activity-container" graded="#{graded}" state="#{state}" model="#{model}" mode="#{mode}" user_id="#{user.id}" section_slug="#{section_slug}" bib_params="#{Base.encode64(bib_params_json)}" #{maybe_group_id(group_id)}#{maybe_survey_id(survey_id)}></#{tag}>\n|
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
              ~s|<h4 class="activity-purpose |,
              Oli.Utils.Slug.slugify(purpose),
              ~s|">|,
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
