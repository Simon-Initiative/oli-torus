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
  alias Oli.Rendering.Utils, as: RenderUtils
  alias Oli.Delivery.Attempts.Core.PartAttempt

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
      "oli_multi_input" -> "Multi input submission"
      "oli_image_coding" -> "Image coding submission"
      "oli_adaptive" -> "Adaptive submission"
      _unregistered -> "Activity submission"
    end
  end

  defp get_input(type, part_attempt) do
    try do
      case type do
        # Hints do not record student input
        "HINT" ->
          "HINT"

        "HINT_MSG" ->
          "HINT"

        "ATTEMPT" ->
          part_attempt
          |> handle_input_by_activity()
          # Datashop `<input>` elements have a maximum character count of 255
          |> String.slice(0..254)
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

  def handle_input_by_activity(part_attempt) do
    input = part_attempt.response["input"]

    case activity_type(part_attempt) do
      "oli_short_answer" -> short_answer_input(part_attempt, input)
      "oli_multiple_choice" -> multiple_choice_input(part_attempt, input)
      "oli_check_all_that_apply" -> check_all_that_apply_input(part_attempt, input)
      "oli_ordering" -> ordering_input(part_attempt, input)
      "oli_multi_input" -> multi_input_input(part_attempt, input)
      "oli_image_coding" -> image_coding_input(part_attempt, input)
      "oli_adaptive" -> adaptive_input(part_attempt, input)
      _unregistered -> unregistered_activity_input(part_attempt, input)
    end
  end

  # SA student input is the string entered in the html input field
  def short_answer_input(_part_attempt, input) do
    input
  end

  # MC Student input looks like "choiceId"
  def multiple_choice_input(part_attempt, input), do: choices_input(part_attempt, input)

  # CATA student input looks like "id1 id2 id3"
  def check_all_that_apply_input(part_attempt, input), do: choices_input(part_attempt, input)

  # Ordering student input looks like "id1 id2 id3"
  def ordering_input(part_attempt, input), do: choices_input(part_attempt, input)

  # Multi input student inputs are split into separate parts.
  # A part corresponds to either a dropdown, numeric, or text input.
  # For dropdown inputs (input like "id1"), model like other activities with choices.
  # For numeric/text, model as short answer input.
  def multi_input_input(part_attempt, input) do
    input_option = Enum.find(all_inputs(part_attempt), &(&1["partId"] == part_attempt.part_id))

    case input_option["inputType"] do
      "dropdown" -> choices_input(part_attempt, input)
      "numeric" -> input
      "text" -> input
    end
  end

  # Image coding are a more complicated case with client-side evaluation.
  # Just give back the raw student input.
  def image_coding_input(_part_attempt, input) do
    input
  end

  # Adaptive inputs are another special case.
  # Just give back the raw student input.
  def adaptive_input(_part_attempt, input) do
    input
  end

  # For non-native OLI activities, we don't know what the model looks like.
  def unregistered_activity_input(_part_attempt, input) do
    input
  end

  defp activity_type(%PartAttempt{} = part_attempt) do
    part_attempt.activity_attempt.revision.activity_type.slug
  end

  def choices_input(part_attempt, input) do
    selected_choices(all_choices(part_attempt), selected_choice_ids(input))
    |> Enum.map(&get_content(&1))
    |> RenderUtils.parse_html_content()
  end

  defp all_choices(part_attempt), do: part_attempt.activity_attempt.transformed_model["choices"]
  defp all_inputs(part_attempt), do: part_attempt.activity_attempt.transformed_model["inputs"]

  defp selected_choice_ids(input), do: String.split(input, " ")

  defp selected_choices(all_choices, selected_ids),
    do: Enum.filter(all_choices, &Enum.member?(selected_ids, &1["id"]))

  defp get_content(content_item), do: maybe_get_model(content_item["content"])

  defp maybe_get_model(%{"model" => model}), do: model
  defp maybe_get_model(contents) when is_list(contents), do: maybe_get_model(hd(contents))
  defp maybe_get_model(content), do: content

  defp select_feedback(%PartAttempt{} = part_attempt) do
    get_content(part_attempt.feedback)
  end
end
