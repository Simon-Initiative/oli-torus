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
  require Logger
  alias Oli.Analytics.Datashop.Utils

  def setup(%{type: type, problem_name: problem_name, part_attempt: part_attempt}) do
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
      "oli_check_all_that_apply" -> "Check all that apply selection"
      _unregistered -> "Action in unregistered activity type"
    end
  end

  defp get_input(type, part_attempt) do
    try do
      case type do
        # Input for hint elements does not record student input
        "HINT" ->
          "HINT"

        "HINT_MSG" ->
          "HINT"

        "ATTEMPT" ->
          input = part_attempt.response["input"]

          case activity_type(part_attempt) do
            # for short answer questions, the input is the text the student entered in the field
            "oli_short_answer" ->
              input
              |> Utils.parse_content()

            # for multiple choice questions, the input is a string id that refers to the selected choice
            "oli_multiple_choice" ->
              choices = part_attempt.activity_attempt.transformed_model["choices"]
              content = Enum.find(choices, &(&1["id"] == input))["content"]

              case content do
                %{"model" => model} -> Utils.parse_content(model)
                _ -> Utils.parse_content(content)
              end

            "oli_check_all_that_apply" ->
              # CATA Input includes all selected choices as "id1 id2 id3"
              selected_choices = String.split(input, " ")
              choices = part_attempt.activity_attempt.transformed_model["choices"]

              contents =
                choices
                |> Enum.filter(fn choice ->
                  Enum.find(
                    selected_choices,
                    fn selected_id -> choice["id"] == selected_id end
                  )
                end)
                |> Enum.map(fn choice -> choice["content"] end)

              contents
              |> Enum.map(fn content_item ->
                case content_item do
                  %{"model" => model} -> Utils.parse_content(model)
                  _ -> Utils.parse_content(content_item)
                end
              end)

            # fallback for future activity types
            _unregistered ->
              "Input in unregistered activity type: " <> input
          end

        "RESULT" ->
          content = part_attempt.feedback["content"]

          case content do
            %{"model" => model} -> Utils.parse_content(model)
            _ -> Utils.parse_content(content)
          end
      end
    rescue
      e ->
        Logger.error(e)

        Logger.error("""
        Error in EventDescriptor.get_input.
        Type: #{type}, part attempt: #{Kernel.inspect(part_attempt)}"
        The input that created this event could not be found.
        """)
    end
  end

  defp activity_type(part_attempt) do
    part_attempt.activity_attempt.revision.activity_type.slug
  end
end
