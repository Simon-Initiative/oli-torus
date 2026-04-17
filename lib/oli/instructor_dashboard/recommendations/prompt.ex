defmodule Oli.InstructorDashboard.Recommendations.Prompt do
  @moduledoc """
  Builds versioned prompt messages for instructor-dashboard recommendations.
  """

  @version "recommendation_prompt_v1"

  @spec version() :: String.t()
  def version, do: @version

  @spec build_messages(map(), keyword()) :: [map()]
  def build_messages(input_contract, _opts \\ []) when is_map(input_contract) do
    [
      %{role: :system, content: system_prompt(input_contract)},
      %{role: :user, content: user_prompt(input_contract)}
    ]
  end

  defp system_prompt(%{signal_summary: %{state: :no_signal}}) do
    """
    You are an expert learning engineer and instructor dashboard analyst. You will be given 1-5 datasets exported from an LMS/assessment system. Each dataset is presented as:

    - A descriptor line explaining what it is
    - A Markdown table containing the data

    Your job is to produce an actionable instructional insight. You must be precise, avoid speculation, and cite the dataset(s) and column names you used.

    Return exactly one sentence. Do not include bullet points, headings, or multiple recommendations.
    If the normalized input indicates `signal_state=no_signal`, state that there is no specific recommendation at this point in time because there is not enough student data.
    Do not invent facts not supported by the tables.
    If you make an inference, label it explicitly as Inference and explain the supporting evidence.
    """
  end

  defp system_prompt(_input_contract) do
    """
    You are an expert learning engineer and instructor dashboard analyst. You will be given 1-5 datasets exported from an LMS/assessment system. Each dataset is presented as:

    - A descriptor line explaining what it is
    - A Markdown table containing the data

    Your job is to produce an actionable instructional insight. You must be precise, avoid speculation, and cite the dataset(s) and column names you used.

    Produce one instructional insight or recommendation total, expressed in one sentence (or at most two short sentences).
    The insight should be the highest-impact finding an instructor or admin should act on right now.

    When forming the insight, consider implicitly:

    - Patterns across datasets (performance, attempts, hints, timing, engagement).
    - Evidence from specific dataset descriptors and column names.
    - Whether the issue concerns students, groups, concepts, or engagement behaviors.
    - What concrete instructor action would most directly address the issue.

    Required constraints:

    - The sentence must reference one dataset descriptor or one course content location.
    - Do not include bullet points, headings, or multiple recommendations.
    - Do not explain your reasoning step-by-step.
    - If evidence is suggestive but not definitive, label it clearly as Inference within the sentence.
    - If no meaningful insight can be supported by the data, say so explicitly in one sentence.

    Rules:

    - Do not invent facts not supported by the tables.
    - If you make an inference, label it explicitly as Inference and explain the supporting evidence.
    - Prefer specific statements over generic advice.
    - If there are multiple datasets, cross-reference them when the evidence supports the same conclusion.
    - If a dataset is empty or clearly incomplete, note it and proceed with what you have.
    - If very little student data is present, it is fine to state "There is no specific recommendation at this point in time, as there isn't enough student data"
    """
  end

  defp user_prompt(input_contract) do
    datasets =
      input_contract
      |> Map.get(:datasets, [])
      |> Enum.map(&render_dataset/1)
      |> Enum.join("\n\n")

    signal_summary = Map.fetch!(input_contract, :signal_summary)
    scope = Map.fetch!(input_contract, :scope)

    """
    Prompt version: #{Map.get(input_contract, :prompt_version, @version)}
    Signal state: #{signal_summary.state}
    No-signal reasons: #{Enum.join(Enum.map(signal_summary.reasons, &to_string/1), ", ")}
    Scope: #{scope.scope_label} (#{scope.container_type})
    Course: #{scope.course_title}

    ### What you have

    #{datasets}

    ### Output requirements

    Produce the final recommendation now.
    """
    |> String.trim()
  end

  defp render_dataset(dataset) do
    """
    Dataset: #{Map.fetch!(dataset, :key)}
    Descriptor: #{Map.fetch!(dataset, :descriptor)}
    #{render_markdown_table(Map.get(dataset, :columns, []), Map.get(dataset, :rows, []))}
    """
    |> String.trim()
  end

  defp render_markdown_table([], _rows), do: "_(no table columns)_"

  defp render_markdown_table(columns, []),
    do: markdown_header(columns) <> "\n" <> markdown_separator(columns)

  defp render_markdown_table(columns, rows) do
    [markdown_header(columns), markdown_separator(columns) | Enum.map(rows, &markdown_row/1)]
    |> Enum.join("\n")
  end

  defp markdown_header(columns),
    do: "| " <> Enum.join(Enum.map(columns, &to_string/1), " | ") <> " |"

  defp markdown_separator(columns),
    do: "| " <> Enum.join(List.duplicate("---", length(columns)), " | ") <> " |"

  defp markdown_row(row) do
    values =
      row
      |> Enum.map(fn
        value when is_float(value) -> Float.to_string(value)
        value -> to_string(value || "")
      end)

    "| " <> Enum.join(values, " | ") <> " |"
  end
end
