defmodule Oli.Conversation.Dialogue do
  require Logger

  import Oli.Conversation.Common

  alias Oli.Repo
  alias Oli.Conversation.Message
  alias Oli.Conversation.ConversationMessage
  alias Oli.Conversation.Functions
  alias Oli.Conversation.Model


  defstruct [
    :model,
    :rendered_messages,
    :messages,
    :response_handler_fn,
    :functions,
    :functions_token_length
  ]

  @token_usage_high_watermark 0.9

  def new(system_message, response_handler_fn, options \\ []) do
    model = options[:model] || Oli.Conversation.Model.default()

    system_message = Message.new(:system, system_message)

    %__MODULE__{
      model: Oli.Conversation.Model.model(model),
      rendered_messages: [],
      messages: [system_message],
      response_handler_fn: response_handler_fn,
      functions: Functions.functions(),
      functions_token_length: Functions.total_token_length()
    }
  end

  def engage(
        %__MODULE__{model: model, messages: messages, response_handler_fn: response_handler_fn} =
          dialogue,
        :async
      ) do
    OpenAI.chat_completion(
      [
        model: model,
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

        _e ->
          Logger.info("Response finished")
      end
    end)
    |> Enum.to_list()
  end

  def engage(
        %__MODULE__{messages: messages, model: model} = dialogue,
        :sync
      ) do
    result =
      OpenAI.chat_completion(
        [
          model: model,
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

  def add_message(
        %__MODULE__{messages: messages, rendered_messages: rendered_messages} = dialog,
        message,
        user_id,
        resource_id,
        section_id
      ) do
    # persist message to database for reviewing conversation history
    create_conversation_message(message, user_id, resource_id, section_id)

    dialog = %{dialog | rendered_messages: rendered_messages ++ [message]}

    %{dialog | messages: messages ++ [message]}
  end

  def summarize(%__MODULE__{messages: messages, model: model} = dialog) do
    summarize_messages =
      case messages do
        [_system | rest] ->
          [Message.new(:system, summarize_prompt()) | rest]
      end

    [system | _rest] = messages

    case OpenAI.chat_completion(
           [model: model, messages: encode_messages(summarize_messages)],
           config(:sync)
         ) do
      {:ok, %{choices: [first | _rest]}} ->
        summary = Message.new(:system, first["message"]["content"])

        messages = [system, summary]

        %{dialog | messages: messages}

      _e ->
        dialog
    end
  end

  def should_summarize?(%__MODULE__{model: model} = dialog) do
    total_token_length(dialog) > Model.token_limit(model) * @token_usage_high_watermark
  end

  def total_token_length(%__MODULE__{
        messages: messages,
        functions_token_length: functions_token_length
      }) do
    Enum.reduce(messages, functions_token_length, fn message, acc ->
      acc + message.token_length
    end)
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

  defp create_conversation_message(message, user_id, resource_id, section_id) do
    attrs =
      message
      |> Map.from_struct()
      |> Map.merge(%{user_id: user_id, resource_id: resource_id, section_id: section_id})

    %ConversationMessage{}
    |> ConversationMessage.changeset(attrs)
    |> Repo.insert()
  end

  def config(:sync) do
    %OpenAI.Config{
      http_options: [recv_timeout: 30000],
      api_key: System.get_env("OPENAI_API_KEY"),
      organization_key: System.get_env("OPENAI_ORG_KEY"),
      api_url: "https://api.openai.com"
    }
  end

  def config(:async) do
    %OpenAI.Config{
      http_options: [recv_timeout: :infinity, stream_to: self(), async: :once],
      api_key: System.get_env("OPENAI_API_KEY"),
      organization_key: System.get_env("OPENAI_ORG_KEY"),
      api_url: "https://api.openai.com"
    }
  end
end
