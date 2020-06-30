
defmodule Oli.Analytics.Datashop.Elements.EventDescriptor do
  @moduledoc """
  <event_descriptor>
    <selection>(ARC-BD-MEASURE QUESTION1 REASON)</selection>
    <action>INPUT-CELL-VALUE</action>
    <input>HINT</input>
  </event_descriptor>

  <event_descriptor>
    <selection>(ARC-BD-MEASURE QUESTION1 REASON)</selection>
    <action>INPUT-CELL-VALUE</action>
    <input>given</input>
  </event_descriptor>
  """
  import XmlBuilder
  alias Oli.Analytics.Datashop.Utils

  def setup(%{ type: type, problem_name: problem_name, part_attempt: part_attempt }) do
    element(:event_descriptor, [
      element(:selection, problem_name),
      element(:action, get_action(part_attempt)),
      element(:input, get_input(type, part_attempt))
    ])
  end

  defp get_action(part_attempt) do
    case activity_type(part_attempt) do
      "oli_short_answer" -> "Short answer input"
      "oli_multiple_choice" -> "Multiple choice selection"
      _unregistered -> "Action in unregistered activity type"
    end
  end

  defp get_input(type, part_attempt) do
    case type do
      # Input for hint elements does not record student input
      "HINT" -> "HINT"
      "HINT_MSG" -> "HINT"
      "ATTEMPT" ->
        input = part_attempt.response["input"]

        case activity_type(part_attempt) do
          # for short answer questions, the input is the text the student entered in the field
          "oli_short_answer" -> input
            |> Utils.parse_content
          # for multiple choice questions, the input is a string id that refers to the selected choice
          "oli_multiple_choice" ->
            choices = part_attempt.activity_attempt.transformed_model["choices"]
            Enum.find(choices, & &1["id"] == input)["content"]
            |> Utils.parse_content
          # fallback for future activity types
          _unregistered -> "Input in unregistered activity type: " <> input
        end
      "RESULT" ->
        part_attempt.feedback["content"]
        |> Utils.parse_content
    end
  end

  defp activity_type(part_attempt) do
    part_attempt.activity_attempt.revision.activity_type.slug
  end
end
