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

        # Attempt messages display the raw student input. For most activities, this is a space-separated
        # string of selected choice IDs, e.g. "id1 id2 id3." Previously, this code mapped the input
        # string of ids to the actual content of the selected choices. However, Datashop `<input>`
        # elements have a maximum character count of 255 chars, so the parsed HTML content of all
        # selected choices is often too long (e.g. ordering inputs displayed the contents of every
        # choice). Each activity also has its own "meaning" for student input - e.g. activities are not
        # required to treat student inputs as lists of choice IDs, so each activity had to be treated
        # differently to show the human-friendly student "selection." The downside of showing the
        # raw input string is that the actual choice content seen by the student is not obvious through
        # Datashop without cross-referencing the IDs.
        "ATTEMPT" ->
          part_attempt
          |> select_input()
          |> Utils.cdata()

        "RESULT" ->
          part_attempt
          |> select_feedback()
          |> Utils.structured_content_to_cdata()
      end
    rescue
      e ->
        Logger.error(e)

        IO.inspect(part_attempt, label: "Error: part attempt")

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

  defp select_input(part_attempt) do
    part_attempt.response["input"]
  end

  defp select_feedback(part_attempt) do
    part_attempt.feedback["content"]["model"]
  end
end
