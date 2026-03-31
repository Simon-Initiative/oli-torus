defmodule Oli.Conversation.LLMFeedback do
  @moduledoc """
  Generates LLM-based feedback for adaptive page trap states.

  Invoked synchronously during activity evaluation when a trap state
  rule has an activation point action of kind "feedback". Uses the
  GenAI completions service to generate personalized feedback based on
  the author's prompt, the student's response, and the screen content.
  """

  require Logger

  alias Oli.GenAI.Execution
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.FeatureConfig
  alias Oli.Conversation.AdaptivePageContextBuilder
  alias Oli.Delivery.Attempts.Core.StudentInput

  @doc """
  Given the author prompt, student response text, and context identifiers,
  invoke GenAI synchronously and return the generated feedback text.

  Returns `{:ok, feedback_text}` on success or `{:error, reason}` on failure.
  """
  def generate(author_prompt, student_input, activity_attempt_guid, section_id, user_id) do
    screen_context = build_screen_context(activity_attempt_guid, section_id, user_id)
    messages = build_messages(author_prompt, student_input, screen_context)

    with {:ok, service_config} <- load_service_config(section_id),
         request_ctx = %{request_type: :llm_feedback, service_config_id: service_config.id},
         {:ok, response} <- Execution.generate(request_ctx, messages, [], service_config) do
      {:ok, normalize_response(response)}
    else
      {:error, reason} ->
        Logger.error("LLM feedback generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_service_config(section_id) do
    try do
      {:ok, FeatureConfig.load_for(section_id, :student_dialogue)}
    rescue
      e ->
        Logger.error(
          "Failed to load GenAI service config for section #{section_id}: #{inspect(e)}"
        )

        {:error, :no_service_config}
    end
  end

  defp build_screen_context(activity_attempt_guid, section_id, user_id) do
    case AdaptivePageContextBuilder.build(activity_attempt_guid, section_id, user_id) do
      {:ok, markdown} -> markdown
      {:error, _} -> ""
    end
  end

  defp build_messages(author_prompt, student_input, screen_context) do
    system_message =
      Message.new(
        :system,
        """
        You are a helpful educational tutor providing feedback on a student's response \
        in an adaptive lesson. Your feedback should be constructive, specific to what the \
        student wrote, and guide them toward understanding.

        Do not reveal the correct answer directly. Instead, help the student think through \
        the problem.

        Keep your response concise (2-4 sentences).
        """
      )

    user_message =
      Message.new(
        :user,
        """
        ## Screen Content
        #{screen_context}

        ## Student's Response
        #{student_input}

        ## Author Instructions
        #{author_prompt}

        Based on the above, provide targeted feedback for the student.
        """
      )

    [system_message, user_message]
  end

  @doc """
  Walk the rules engine results to find the first activation point action
  with kind "feedback" and return its prompt, or nil if none found.
  """
  def find_llm_feedback_prompt(%{"results" => results}) when is_list(results) do
    Enum.find_value(results, fn
      %{"params" => %{"actions" => actions}} when is_list(actions) ->
        Enum.find_value(actions, fn
          %{"type" => "activationPoint", "params" => %{"kind" => "feedback", "prompt" => prompt}}
          when is_binary(prompt) and prompt != "" ->
            prompt

          _ ->
            nil
        end)

      _ ->
        nil
    end)
  end

  def find_llm_feedback_prompt(_), do: nil

  @doc """
  Extract a human-readable representation of the student's input from part_inputs.
  """
  def extract_student_input(part_inputs) when is_list(part_inputs) do
    part_inputs
    |> Enum.map(fn
      %{input: %StudentInput{input: input}} when is_map(input) ->
        input
        |> Map.values()
        |> Enum.map(fn
          %{"value" => value} when is_binary(value) -> value
          %{"value" => value} -> inspect(value)
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.join("; ")

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  def extract_student_input(_), do: ""

  defp normalize_response(response) when is_binary(response), do: response

  defp normalize_response(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content),
       do: content

  defp normalize_response(other), do: inspect(other)
end
