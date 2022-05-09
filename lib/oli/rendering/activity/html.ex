defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  require Logger

  @behaviour Oli.Rendering.Activity

  defp get_flattened_activity_model(page_content, activity_id, activity_map) do
    activity_model = activity_map[activity_id].model
    [first | _tail] = page_content
    sequenceEntry = Enum.find(Map.get(first, "children", []), fn(%{"activity_id" => child_activity_id}) -> child_activity_id == activity_id end)
    case sequenceEntry do
      nil ->
        Logger.error("Could not find activity_id #{activity_id} in page_content sequence")
        activity_model
      _ ->
        parent_activity_id = Map.get(sequenceEntry, "layerRef", nil)
        # if there is a parent, need to merge the model with the parent model, and recursively do so all the way up
        sequenceCustom = Map.get(sequenceEntry, "custom")
        sequenceId = Map.get(sequenceCustom, "sequenceId")
        mapped = Poison.decode!(HtmlEntities.decode(activity_model))
        Map.put(mapped, "id", sequenceId)
        |> Poison.encode!
        |> HtmlEntities.encode
    end
  end

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          mode: mode,
          user: user,
          resource_attempt: resource_attempt
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
    activity_summary = activity_map[activity_id]

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

        model_json = case tag do
          "oli-adaptive-delivery" ->
            page_model = Map.get(resource_attempt.content, "model")
            get_flattened_activity_model(page_model, activity_id, activity_map)

          _ -> activity_summary.model
        end


        section_slug = context.section_slug

        activity_html =
          case mode do
            :instructor_preview ->
              [
                "<#{tag} model=\"#{model_json}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>\n"
              ]

            _ ->
              [
                "<#{tag} class=\"activity-container\" graded=\"#{graded}\" state=\"#{state}\" model=\"#{model_json}\" mode=\"#{mode}\" user_id=\"#{user.id}\" section_slug=\"#{section_slug}\"></#{tag}>\n"
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
