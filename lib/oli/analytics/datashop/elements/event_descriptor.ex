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
      element(:action, get_action(part_attempt)),
      element(:input, get_input(type, part_attempt))
    ])
  end

  defp get_action(part_attempt) do
    case activity_type(part_attempt) do
      "oli_short_answer" -> "Short answer submission"
      "oli_multiple_choice" -> "Multiple choice submission"
      "oli_check_all_that_apply" -> "Check all that apply submission"
      "oli_ordering" -> "Ordering submission"
      _other -> "Student activity submission"
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
            "oli_short_answer" ->
              # SA student input is just the entered text
              input
              |> Utils.parse_content()

            "oli_multiple_choice" ->
              # MC student input looks like "id1" where id1 is the selected choice
              part_attempt.activity_attempt.transformed_model["choices"]
              |> Enum.find(fn choice -> choice["id"] == input end)
              |> Map.get("content")
              |> case do
                %{"model" => model} -> Utils.parse_content(model)
                content -> Utils.parse_content(content)
              end

            "oli_check_all_that_apply" ->
              # CATA student input looks like "id1 id2 id3" where id1 id2 id3 are the selected choices
              part_attempt.activity_attempt.transformed_model["choices"]
              |> Enum.filter(fn choice ->
                Enum.find(
                  String.split(input, " "),
                  fn selected_id -> choice["id"] == selected_id end
                )
              end)
              |> Enum.map(fn choice -> choice["content"]["model"] end)
              |> Enum.map(fn choice_content ->
                IO.inspect(Utils.parse_content(choice_content), label: "Parsed attempt 1")
              end)

            "oli_ordering" ->
              # Ordering student input looks like "id1 id2 id3" where id1 id2 id3 are the selected choices
              part_attempt.activity_attempt.transformed_model["choices"]
              |> Enum.filter(fn choice ->
                Enum.find(
                  String.split(input, " "),
                  fn selected_id -> choice["id"] == selected_id end
                )
              end)
              |> Enum.map(fn choice -> choice["content"]["model"] end)
              |> Enum.map(fn choice_content -> Utils.parse_content(choice_content) end)

            # fallback for other activity types
            _other ->
              {:cdata, input}
          end

        "RESULT" ->
          content = part_attempt.feedback["content"]["model"]
          IO.inspect(content, label: "Result content")
          IO.inspect(Utils.parse_content(content), label: "Parsed result 1")
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
