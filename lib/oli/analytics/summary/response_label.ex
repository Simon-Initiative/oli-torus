defmodule Oli.Analytics.Summary.ResponseLabel do

  defstruct [
    :response,
    :label
  ]

  def build(part_attempt, "oli_file_upload") do
    tbd()
  end

  def build(part_attempt, "oli_adaptive") do
    tbd()
  end


  def build(part_attempt, "oli_custom_dnd") do
    tbd()
  end

  def build(part_attempt, "oli_image_coding") do
    tbd()
  end

  def build(part_attempt, "oli_image_hotspot") do
    tbd()
  end

  def build(part_attempt, "oli_likert") do
    tbd()
  end

  def build(part_attempt, "oli_multi_input") do
    tbd()
  end

  def build(part_attempt, "oli_multiple_choice"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_ordering"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_check_all_that_apply"), do: from_choices(part_attempt)

  def build(part_attempt, "oli_embedded") do
    tbd()
  end



  def build(part_attempt, "oli_short_answer") do
    case part_attempt.response do
      %{"input" => input} when is_binary(input) ->
        to_struct(input, input)
      _ ->
        empty()
    end
  end

  def build(part_attempt, "oli_vlab") do
    tbd()
  end

  defp select_model(attempt, revision) do
    case attempt.transformed_model do
      nil -> revision.content
      transformed_model -> transformed_model
    end
  end

  defp from_choices(part_attempt, labeller \\ &letters_from_choices/2) do
    choices = part_attempt.activity_revision.content
    |> Map.get("choices")

     case part_attempt.response do
      %{"input" => nil} ->
        to_struct("No answer", "#{part_attempt.activity_revision.resource_id}")

      %{"input" => input} when is_binary(input) ->
        labeller.(choices, String.split(input, " "))
        |> to_struct(input)

      _ ->
        to_struct("", "#{part_attempt.activity_revision.resource_id}")
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

  defp tbd(), do: to_struct("TBD", "TBD")
  defp empty(), do: to_struct("Empty", "")

end
