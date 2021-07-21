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

  def setup(type, %{problem_name: problem_name, part_attempt: part_attempt}) do
    element(:event_descriptor, [
      element(:selection, problem_name),
      element(:action, "Activity submission"),
      element(:input, get_input(type, part_attempt))
    ])
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
          part_attempt
          |> select_input()
          # |> map_to_choice_content(part_attempt)
          |> Utils.cdata()

        "RESULT" ->
          part_attempt
          |> select_feedback()
          |> Utils.structured_content_to_cdata()
      end
    rescue
      e ->
        Logger.error(e)

        Logger.error("""
        Error in EventDescriptor.get_input.
        Type: #{type}, part attempt: #{Kernel.inspect(part_attempt)}"
        The input that created this event could not be found.
        """)

        # Return a generic "Student input" string for datashop if the actual input
        # cannot be parsed just to give a hint as to what the message is for.
        "Student input"
    end
  end

  defp activity_type(part_attempt) do
    part_attempt.activity_attempt.revision.activity_type.slug
  end

  defp select_input(part_attempt) do
    part_attempt.response["input"]
  end

  defp select_feedback(part_attempt) do
    part_attempt.feedback["content"]["model"]
  end

  defp map_to_choice_content(input, part_attempt) do
    case activity_type(part_attempt) do
      "oli_short_answer" ->
        # SA student input is just the entered text
        input

      "oli_multiple_choice" ->
        # MC input is just the selected choice ID
        choice_content_from_input(part_attempt, input)

      "oli_check_all_that_apply" ->
        # CATA is space-separated selected choice IDs
        choice_content_from_input(part_attempt, input)

      "oli_ordering" ->
        # Ordering input is space-separated selected choice IDs
        choice_content_from_input(part_attempt, input)

      _other ->
        # Fallback for other activity types. This shouldn't cause a problem
        # if another activity type is used to create data, but the actual content
        # of the student submission will not be shown in Datashop.
        input
    end
  end

  defp choice_content_from_input(part_attempt, input) do
    part_attempt.activity_attempt.transformed_model["choices"]
    |> Enum.filter(fn choice ->
      Enum.find(
        String.split(input, " "),
        fn selected_id -> choice["id"] == selected_id end
      )
    end)
    |> IO.inspect(label: "Found choices")
    |> Enum.map(fn choice -> choice["content"]["model"] end)
    |> IO.inspect(label: "choice content items")
    |> Enum.map(fn content_model -> Utils.parse_content(content_model) end)
    |> IO.inspect(label: "parsed")
    |> Enum.join("\n")
  end
end
