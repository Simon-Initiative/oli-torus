defmodule Oli.Delivery.Attempts.FeedbackText do
  @moduledoc """
  Extracts plain feedback text from activity and part attempt data.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt}
  alias Oli.Repo

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
  Fetches manually-graded feedback text for resource attempts without preloading
  full activity and part attempt graphs.
  """
  def manual_feedback_texts_by_resource_attempt_guid([]), do: %{}

  def manual_feedback_texts_by_resource_attempt_guid(resource_attempts) do
    resource_attempt_ids = Enum.map(resource_attempts, & &1.id)

    feedback_texts_by_resource_attempt_id =
      resource_attempt_ids
      |> manual_part_attempt_feedback_query()
      |> Repo.all()
      |> Enum.reduce(%{}, fn {resource_attempt_id, feedback}, acc ->
        feedback_texts = extract_from_part_attempt(%{feedback: feedback})

        Map.update(acc, resource_attempt_id, [feedback_texts], fn existing ->
          [feedback_texts | existing]
        end)
      end)

    Map.new(resource_attempts, fn attempt ->
      feedback_texts =
        feedback_texts_by_resource_attempt_id
        |> Map.get(attempt.id, [])
        |> Enum.reverse()
        |> List.flatten()
        |> Enum.uniq()

      {attempt.attempt_guid, feedback_texts}
    end)
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

  defp extract_text(_), do: []

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

  defp manual_part_attempt_feedback_query(resource_attempt_ids) do
    from(pa in PartAttempt,
      join: aa in ActivityAttempt,
      on: pa.activity_attempt_id == aa.id,
      where:
        aa.resource_attempt_id in ^resource_attempt_ids and pa.grading_approach == :manual and
          not is_nil(pa.feedback),
      order_by: [asc: aa.id, asc: pa.id],
      select: {aa.resource_attempt_id, pa.feedback}
    )
  end
end
