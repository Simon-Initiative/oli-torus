defmodule Oli.Analytics.Summary.ResponseLabel do

  defstruct [
    :response,
    :label
  ]

  def build(_part_attempt, "oli_file_upload"), do: unsupported()
  def build(_part_attempt, "oli_adaptive"), do: unsupported()
  def build(_part_attempt, "oli_embedded"), do: unsupported()
  def build(_part_attempt, "oli_image_coding"), do: unsupported()

  def build(part_attempt, "oli_multiple_choice"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_ordering"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_check_all_that_apply"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_image_hotspot"), do: from_choices(part_attempt)

  def build(part_attempt, "oli_custom_dnd") do
    parts_as_choices = part_attempt.activity_revision.content
    |> Map.get("authoring", %{})
    |> Map.get("parts", [])

    from_choices_helper(parts_as_choices, part_attempt, &letters_from_choices/2)
  end

  def build(part_attempt, "oli_likert") do

    order_descending = part_attempt.activity_revision.content
    |> Map.get("orderDescending", false)

    from_choices(part_attempt, fn choices, ids ->
      if order_descending do
        numbers_from_choices(Enum.reverse(choices), ids)
      else
        numbers_from_choices(choices, ids)
      end
    end)

  end

  def build(part_attempt, "oli_multi_input") do
    case Enum.find(part_attempt.activity_revision.content["inputs"], fn input -> input["partId"] == part_attempt.id end) do
      %{"inputType" => "text"} ->
        build(part_attempt, "oli_short_answer")
      %{"inputType" => "dropdown"} = input ->

        choices_for_this_part = Map.get(input, "choiceIds", []) |> MapSet.new()

        part_attempt.activity_revision.content
        |> Map.get("choices", [])
        |> Enum.filter(fn c -> MapSet.member?(choices_for_this_part, c["id"]) end)
        |> from_choices_helper(part_attempt, &letters_from_choices/2)

      %{"inputType" => "math"} ->
        build(part_attempt, "oli_short_answer")
      %{"inputType" => "numeric"} ->
        build(part_attempt, "oli_short_answer")
      %{"inputType" => "vlabvalue"} ->
        build(part_attempt, "oli_short_answer")
      _ ->
        unsupported()
    end
  end

  def build(part_attempt, "oli_vlab") do
    # identical to multi input, so delegate
    build(part_attempt, "oli_multi_input")
  end

  def build(part_attempt, "oli_short_answer") do
    case part_attempt.response do
      %{"input" => input} when is_binary(input) ->
        to_struct(input, input)
      _ ->
        empty()
    end
  end

  def build(_part_attempt, _dynamically_registered), do: unsupported()

  defp from_choices(part_attempt, labeller \\ &letters_from_choices/2) do
    part_attempt.activity_revision.content
    |> Map.get("choices")
    |> from_choices_helper(part_attempt, labeller)
  end

  defp from_choices_helper(choices, part_attempt, labeller) do
     case part_attempt.response do
      %{"input" => nil} ->
        to_struct("No answer", "")

      %{"input" => input} when is_binary(input) ->
        labeller.(choices, String.split(input, " "))
        |> to_struct(input)

      _ ->
        to_struct("No answer", "")
    end
  end

  defp letters_from_choices(nil, _ids), do: "Empty"
  defp letters_from_choices(choices, ids) do

    choice_labels = Enum.with_index(choices)
    |> Enum.map(
      fn {choice, index} ->

        selected_choice = case choice do
          c when is_map(c) -> Map.get(choice,"id")
          _ -> nil
        end

        {selected_choice, <<index + 65 :: utf8>>}

    end)
    |> Map.new()

    Enum.map(ids, fn id -> Map.get(choice_labels, id) end)
    |> Enum.join(", ")
  end

  defp numbers_from_choices(choices, ids) do
    choice_labels = Enum.with_index(choices)
    |> Enum.map(fn {choice, index} -> {choice["id"], index + 1} end)
    |> Map.new()

    Enum.map(ids, fn id -> Map.get(choice_labels, id) end)
    |> Enum.join(", ")
  end

  defp to_struct(label, response) do
    %__MODULE__{
      response: response,
      label: label
    }
  end

  defp unsupported(), do: to_struct("unsupported", "unsupported")
  defp empty(), do: to_struct("No answer", "")

end
