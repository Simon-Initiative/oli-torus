defmodule Oli.GenAI.Completions.OpenAIProvider do

  @behaviour Oli.GenAI.Completions.Provider

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{} = registered_model, options \\ []) do
    OpenAI.chat_completion(
      [
        model: model,
        messages: encode_messages(messages),
        functions: functions
      ],
      config(:sync, registered_model)
    )
  end

  def stream(messages, functions, %RegisteredModel{} = registered_model, response_handler_fn, options \\ []) do
    OpenAI.chat_completion(
      [
        model: model,
        messages: encode_messages(messages),
        functions: functions,
        stream: true
      ],
      config(:async, registered_model)
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

  defp delta(chunk) do
    case chunk["choices"] do
      [] -> {:finished}
      [%{"finish_reason" => "stop"}] -> {:finished}
      [%{"delta" => %{"function_call" => content}}] -> {:delta, :function_call, content}
      [%{"delta" => %{"content" => content}}] -> {:delta, :content, content}
      _ -> {:finished}
    end
  end

  defp encode_messages(messages) do
    Enum.map(messages, fn message ->
      case message.name do
        nil -> %{role: message.role, content: message.content}
        _ -> %{role: message.role, content: message.content, name: message.name}
      end
    end)
  end

  defp config(:sync, %RegisteredModel{} = registered_model) do

    url = Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
      "model" => registered_model.model,
      "api_key" => System.get_env(registered_model.api_key_variable_name),
      "secondary_api_key" => System.get_env(registered_model.secondary_api_key_variable_name)
    })

    %OpenAI.Config{
      http_options: [recv_timeout: 30000],
      api_key: System.get_env(registered_model.api_key_variable_name),
      organization_key: System.get_env(registered_model.secondary_api_key_variable_name),
      api_url: url
    }
  end

  defp config(:async, %RegisteredModel{} = registered_model) do

    url = Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
      "model" => registered_model.model,
      "api_key" => System.get_env(registered_model.api_key_variable_name),
      "secondary_api_key" => System.get_env(registered_model.secondary_api_key_variable_name)
    })

    %OpenAI.Config{
      http_options: [recv_timeout: :infinity, stream_to: self(), async: :once],
      api_key: System.get_env(registered_model.api_key_variable_name),
      organization_key: System.get_env(registered_model.secondary_api_key_variable_name),
      api_url: url
    }
  end

end
