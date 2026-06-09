defmodule Oli.Delivery.Attempts.FeedbackText do
  @moduledoc """
  Extracts plain feedback text from activity and part attempt data.
  """

  require Logger

  @doc """
  Extracts feedback text from activity attempts.
  """
  def extract_feedback_text(activity_attempts) do
    activity_attempts
    |> Enum.map(&extract_from_activity_attempt/1)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Extracts only manually-graded feedback text from activity attempts.
  """
  def extract_manual_feedback_text(activity_attempts) do
    activity_attempts
    |> Enum.map(&extract_manual_from_activity_attempt/1)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Extracts feedback text from an activity attempt with part attempts.
  """
  def extract_from_activity_attempt(%{part_attempts: part_attempts}) do
    part_attempts
    |> Enum.map(&extract_from_part_attempt/1)
  end

  def extract_from_activity_attempt(_), do: []

  @doc """
  Extracts feedback text from a part attempt.
  """
  def extract_from_part_attempt(%{feedback: feedback}) when is_map(feedback),
    do: extract_feedback_entries(feedback)

  def extract_from_part_attempt(%{feedback: nil}), do: []
  def extract_from_part_attempt(_), do: []

  defp extract_manual_from_activity_attempt(%{part_attempts: part_attempts}) do
    part_attempts
    |> Enum.filter(&manual_grading_part_attempt?/1)
    |> Enum.map(&extract_from_part_attempt/1)
  end

  defp extract_manual_from_activity_attempt(_), do: []

  defp manual_grading_part_attempt?(%{grading_approach: :manual}), do: true
  defp manual_grading_part_attempt?(%{grading_approach: "manual"}), do: true
  defp manual_grading_part_attempt?(_), do: false

  defp extract_feedback_entries(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(&extract_text/1)
    |> List.flatten()
    |> Enum.reject(&blank_text?/1)
  end

  defp extract_feedback_entries(%{"content" => %{"model" => model}}) when is_list(model) do
    model
    |> Enum.map(&extract_text/1)
    |> List.flatten()
    |> Enum.reject(&blank_text?/1)
  end

  defp extract_feedback_entries(%{"content" => content}) when is_map(content) do
    content
    |> Enum.map(&extract_text/1)
    |> List.flatten()
    |> Enum.reject(&blank_text?/1)
  end

  defp extract_feedback_entries(%{"partsLayout" => parts_layout}) when is_list(parts_layout) do
    parts_layout
    |> Enum.flat_map(fn part ->
      part
      |> get_in(["custom", "nodes"])
      |> case do
        nodes when is_list(nodes) ->
          [extract_adaptive_nodes_text(nodes)]

        _ ->
          []
      end
    end)
    |> Enum.reject(&blank_text?/1)
    |> Enum.reject(&(&1 == "No text available"))
  end

  defp extract_feedback_entries(_), do: []

  defp extract_text(%{"children" => children}) do
    children
    |> Enum.map(& &1["text"])
    |> Enum.join(" ")
  end

  defp extract_text({"model", model}) do
    Enum.map(model, &extract_text/1)
  end

  defp extract_text(other) do
    Logger.error("Could not parse feedback text from #{inspect(other)}")
    []
  end

  defp extract_adaptive_nodes_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_adaptive_node_text/1)
    |> Enum.join(" ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_adaptive_nodes_text(_), do: ""

  defp extract_adaptive_node_text(%{"text" => text}) when is_binary(text), do: text

  defp extract_adaptive_node_text(%{"children" => children}) when is_list(children) do
    children
    |> Enum.map(&extract_adaptive_node_text/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp extract_adaptive_node_text(_), do: ""

  defp blank_text?(text) when is_binary(text), do: String.trim(text) == ""
  defp blank_text?(_), do: true
end
