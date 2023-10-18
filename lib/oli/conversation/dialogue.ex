defmodule Oli.Conversation.Dialogue do
  require Logger
  alias Oli.Conversation.Message

  defstruct [
    :messages,
    :response_handler_fn,
    :functions
  ]

  def init(system_message, response_handler_fn) do
    %__MODULE__{
      messages: [%Message{role: :system, content: system_message}],
      response_handler_fn: response_handler_fn,
      functions: [
        %{
          name: "up_next",
          description:
            "Returns the next scheduled lessons in the course as a list of objects with the following keys: title, url, due_date, num_attempts_taken",
          parameters: %{
            type: "object",
            properties: %{
              current_user_id: %{
                type: "integer",
                description: "The current student's user id"
              },
              section_id: %{
                type: "integer",
                description: "The current course section's id"
              }
            },
            required: ["current_user_id", "section_id"]
          }
        },
        %{
          name: "avg_score_for",
          description:
            "Returns average score across all scored assessments, as a floating point number between 0 and 1, for a given user and section",
          parameters: %{
            type: "object",
            properties: %{
              current_user_id: %{
                type: "integer",
                description: "The current student's user id"
              },
              section_id: %{
                type: "integer",
                description: "The current course section's id"
              }
            },
            required: ["current_user_id", "section_id"]
          }
        }
      ]
    }
  end

  def engage(
        %__MODULE__{messages: messages, response_handler_fn: response_handler_fn} = dialogue,
        :async
      ) do
    OpenAI.chat_completion(
      [
        model: "gpt-3.5-turbo",
        messages: encode_messages(messages),
        functions: dialogue.functions,
        stream: true
      ],
      config(:async)
    )
    |> Stream.each(fn response ->
      case delta(response) do
        {:delta, type, content} ->
          response_handler_fn.(dialogue, type, content)

        e ->
          IO.inspect(e)
          Logger.info("Response finished")
      end
    end)
    |> Enum.to_list()
    |> IO.inspect()
  end

  def engage(
        %__MODULE__{messages: messages, response_handler_fn: _response_handler_fn} = dialogue,
        :sync
      ) do
    result =
      OpenAI.chat_completion(
        [
          model: "gpt-3.5-turbo",
          messages: encode_messages(messages),
          functions: dialogue.functions
        ],
        config(:sync)
      )

    result
  end

  defp encode_messages(messages) do
    Enum.map(messages, fn message ->
      case message.name do
        nil -> %{role: message.role, content: message.content}
        _ -> %{role: message.role, content: message.content, name: message.name}
      end
    end)
  end

  def add_message(%__MODULE__{messages: messages} = dialog, message) do
    %{dialog | messages: messages ++ [message]}
  end

  defp delta(chunk) do
    case chunk["choices"] do
      [] -> {:finished}
      [%{"finish_reason" => "stop"}] -> {:finished}
      [%{"delta" => %{"function_call" => content}}] -> {:delta, :function_call, content}
      [%{"delta" => %{"content" => content}}] -> {:delta, :content, content}
      _ -> {:finished}
    end
  end

  defp config(:sync) do
    %OpenAI.Config{
      http_options: [recv_timeout: 30000],
      api_key: System.get_env("OPENAI_API_KEY"),
      organization_key: System.get_env("OPENAI_ORG_KEY"),
      api_url: "https://api.openai.com"
    }
  end

  defp config(:async) do
    %OpenAI.Config{
      http_options: [recv_timeout: :infinity, stream_to: self(), async: :once],
      api_key: System.get_env("OPENAI_API_KEY"),
      organization_key: System.get_env("OPENAI_ORG_KEY"),
      api_url: "https://api.openai.com"
    }
  end
end
