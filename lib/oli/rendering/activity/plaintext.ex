defmodule Oli.Rendering.Activity.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Activity

  def activity(
        %Context{
          activity_map: activity_map,
          mode: mode,
          group_id: _group_id,
          survey_id: _survey_id
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

        error(context, activity, {:activity_missing, error_id, error_msg})

      _ ->
        tag =
          case mode do
            :instructor_preview -> activity_summary.authoring_element
            _ -> activity_summary.delivery_element
          end

        [
          "[Activity '#{tag}']"
          # "[Question Stem: #{activity_summary.unencoded_model["stem"]}]",
        ]
    end
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
