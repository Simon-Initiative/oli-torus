defmodule Oli.InstructorDashboard.Recommendations.Prompt do
  @moduledoc """
  Builds versioned prompt messages for instructor-dashboard recommendations.
  """

  @version "recommendation_prompt_v1"
  @data_placeholder "\#{data}"
  @default_no_signal_prompt """
  You are an expert learning engineer and instructor dashboard analyst. You will be given 1-5 datasets exported from an LMS/assessment system. Each dataset is presented as:

  - A descriptor line explaining what it is
  - A Markdown table containing the data

  Your job is to produce an actionable instructional insight. You must be precise, avoid speculation, and cite the dataset(s) and column names you used.

  Return exactly one sentence. Do not include bullet points, headings, or multiple recommendations.
  If the normalized input indicates `signal_state=no_signal`, state that there is no specific recommendation at this point in time because there is not enough student data.
  Do not invent facts not supported by the tables.
  If you make an inference, label it explicitly as Inference and explain the supporting evidence.
  """

  @default_ready_prompt """
  You are an expert learning engineer and instructor dashboard analyst. You will be given 1-5 datasets exported from an LMS/assessment system. Each dataset is presented as:

  - A descriptor line explaining what it is
  - A Markdown table containing the data

  Your job is to produce an actionable instructional insight. You must be precise and avoid speculation. Instructors do not revise course content. They take actions like early intervention with students, providing additional materials, or focusing on a topic in class through hands-on activities.

  ### What you have

  #{@data_placeholder}

  ### Output requirements

  Produce one instructional insight or recommendation total, expressed in fewer than 200 characters.
  The insight should be the highest-impact finding that an instructor should act on right now.

  When forming the insight, consider (implicitly -- do not enumerate):

  - Patterns across datasets (performance, attempts, hints, timing, engagement).
  - Evidence from specific dataset descriptors and column names.
  - Whether the issue concerns students, groups, concepts, or engagement behaviors.
  - What concrete instructor action would most directly address the issue.
  - Where is the class in the schedule? Recommendations are most helpful when they relate to what we are now covering in the course.

  ### Required structure
  - What's happening (signal)
  - Why it matters (interpretation)
  - What to consider doing (suggested action)

  ### Tone guidelines
  - Supportive, not prescriptive
  - Transparent, not "all-knowing"
  - Acts like a trusted TA, not an evaluator
  - Uses common language

  #### Required constraints

  - Do not include bullet points, headings, or multiple recommendations.
  - Do not explain your reasoning step-by-step.
  - Use plain language, no jargon
  - If evidence is suggestive but not definitive, label it clearly as an inference within the sentence.
  - If no meaningful insight can be supported by the data, say so explicitly in one sentence.
  - Round numbers to the hundredth decimal place

  #### Example format (illustrative only)

  "Several students are progressing into Unit 4, but a sizable group is showing low proficiency on core plant biology objectives, particularly cell structure and photosynthesis. You may want to revisit these concepts or assign additional practice before moving further into the unit."

  ### Example format (illustrative only)

  "Proficiency is strong among students who reach Module 6 (92%), but only 72% have progressed this far. Consider sending a brief reminder or adjusting pacing to help more students reach this module."

  #### Rules

  - Do not invent facts not supported by the tables.
  - If the class is performing well, it is fine to point this out
  - If you make an inference, label it explicitly as Inference and explain the supporting evidence.
  - Prefer specific statements over generic advice.
  - If there are multiple datasets, you should cross-reference them (e.g., connect performance to engagement).
  - If a dataset is empty or clearly incomplete, note it and proceed with what you have.
  - If very little student data is present, it is fine to state "There is no specific recommendation at this point in time, as there isn't enough student data"

  Begin now.
  """

  @spec version() :: String.t()
  def version, do: @version

  @spec default_template() :: String.t()
  def default_template, do: String.trim(@default_ready_prompt)

  @spec build_messages(map(), keyword()) :: [map()]
  def build_messages(input_contract, opts \\ []) when is_map(input_contract) do
    rendered_prompt = input_contract |> system_prompt(opts) |> render_prompt(input_contract)

    [%{role: :system, content: rendered_prompt}]
  end

  defp system_prompt(input_contract, opts) do
    case opts |> Keyword.get(:prompt_template) |> normalize_prompt_template() do
      nil ->
        default_system_prompt(input_contract)

      prompt_template ->
        prompt_template
    end
  end

  defp default_system_prompt(%{signal_summary: %{state: :no_signal}}),
    do: String.trim(@default_no_signal_prompt)

  defp default_system_prompt(_input_contract), do: default_template()

  defp normalize_prompt_template(prompt_template) when is_binary(prompt_template) do
    case String.trim(prompt_template) do
      "" -> nil
      _ -> prompt_template
    end
  end

  defp normalize_prompt_template(_), do: nil

  defp render_prompt(prompt_template, input_contract) do
    datasets =
      input_contract
      |> Map.get(:datasets, [])
      |> Enum.map(&render_dataset/1)
      |> Enum.join("\n\n")

    if String.contains?(prompt_template, @data_placeholder) do
      String.replace(prompt_template, @data_placeholder, datasets)
    else
      String.trim_trailing(prompt_template) <> "\n\n" <> datasets
    end
  end

  defp render_dataset(dataset) do
    """
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
