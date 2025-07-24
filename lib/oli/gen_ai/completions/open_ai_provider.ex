defmodule Oli.GenAI.Completions.OpenAIProvider do

  require Logger

  @behaviour Oli.GenAI.Completions.Provider

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{model: model} = registered_model, _options \\ []) do
    OpenAI.chat_completion(
      [
        model: model,
        messages: encode_messages(messages),
        functions: functions
      ],
      config(:sync, registered_model)
    )
  end

  def stream(messages, functions, %RegisteredModel{model: model} = registered_model, response_handler_fn, _options \\ []) do

    OpenAI.chat_completion(
      [
        model: model,
        messages: encode_messages(messages),
        functions: functions,
        stream: true
      ],
      config(:async, registered_model)
    )
    |> Stream.each(fn chunk ->
        process_stream_chunk(chunk)
        |> response_handler_fn.()
      end)
    |> Enum.to_list()
  end

  defp process_stream_chunk(chunk) do

    IO.inspect(chunk, label: "OpenAI Stream Chunk")

    case chunk["choices"] do
      [] ->
        {:error}
      [%{"finish_reason" => "stop"}] ->
        {:tokens_finished}
      [%{"finish_reason" => "function_call"}] ->
        {:function_call_finished}
      [%{"delta" => %{"function_call" => content}}] ->

        # open ai doesn't have the notion of an id for the function call
        # so we just the key but use nil
        content = Map.put(content, "id", nil)

        {:function_call, content}
      [%{"delta" => %{"content" => content}}] ->
        {:tokens_received, content}
      _ ->
        {:error}
    end
  end

  defp encode_messages(messages) do

    # Delete the id and input from messages and open ai does not require these
    # for function calling
    Enum.map(messages, fn message ->
      Map.delete(message, :id)
      |> Map.delete(:input)
    end)
    |> Enum.map(fn message ->
      case message.name do
        nil -> %{role: message.role, content: message.content}
        _ -> %{role: message.role, content: message.content, name: message.name}
      end
    end)
  end

  defp config(:sync, %RegisteredModel{} = registered_model) do

    url = Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
      "model" => registered_model.model,
      "api_key" => read_var(registered_model.api_key_variable_name),
      "secondary_api_key" => read_var(registered_model.secondary_api_key_variable_name)
    })

    %OpenAI.Config{
      http_options: [recv_timeout: 30000],
      api_key: read_var(registered_model.api_key_variable_name),
      organization_key: read_var(registered_model.secondary_api_key_variable_name),
      api_url: url
    }
  end

  defp config(:async, %RegisteredModel{} = registered_model) do

    url = Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
      "model" => registered_model.model,
      "api_key" => read_var(registered_model.api_key_variable_name),
      "secondary_api_key" => read_var(registered_model.secondary_api_key_variable_name)
    })

    %OpenAI.Config{
      http_options: [recv_timeout: :infinity, stream_to: self(), async: :once],
      api_key: read_var(registered_model.api_key_variable_name),
      organization_key: read_var(registered_model.secondary_api_key_variable_name),
      api_url: url
    }
  end

  defp read_var(nil), do: ""
  defp read_var(key) do
    System.get_env(key)
  end

end
