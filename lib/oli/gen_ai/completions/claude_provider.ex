defmodule Oli.GenAI.Completions.ClaudeProvider do
  require Logger

  @moduledoc """
  A provider for Claude 3.x models using the Anthropix library.

  This module implements the `Oli.GenAI.Completions.Provider` behaviour
  and provides functions to generate completions and stream responses
  from Claude models using the Anthropix client.

  Claude models do not support system messages, so they are converted to user messages.

  Function results are also converted to user messages.

  NOTE: This provider does not support Claude 4 models as those models require
  a different function calling (tool) mechanism.
  """

  @behaviour Oli.GenAI.Completions.Provider

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{model: model} = registered_model) do
    client = create_client(registered_model.api_key_variable_name)

    case Anthropix.chat(client,
           model: model,
           messages: encode_messages(messages),
           tools: encode_functions(functions)
         ) do
      {:ok, response} ->
        full_text =
          Enum.reduce(response["content"], "", fn content, acc ->
            case content do
              %{"type" => "text", "text" => text} -> acc <> text
              _ -> acc
            end
          end)

        {:ok, full_text}

      {:error, reason} ->
        Logger.error("Failed to generate response: #{inspect(reason)}")
        {:error, "Failed to generate response"}
    end
  end

  def stream(
        messages,
        functions,
        %RegisteredModel{model: model} = registered_model,
        response_handler_fn
      ) do
    client = create_client(registered_model.api_key_variable_name)

    case Anthropix.chat(client,
           model: model,
           messages: encode_messages(messages),
           tools: encode_functions(functions),
           stream: true
         ) do
      {:ok, stream} ->
        consume_stream(stream, response_handler_fn)
        :ok

      # Network-level failure: timeout, DNS error, connection refused, etc.
      {:error, %Mint.TransportError{reason: reason}} ->
        Logger.error("Anthropix HTTP failure: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp consume_stream(stream, response_handler_fn) do
    Stream.transform(stream, nil, fn chunk, state ->
      case chunk["type"] do
        "content_block_start" ->
          case chunk["content_block"] do
            %{"type" => "text"} ->
              response_handler_fn.({:tokens_received, chunk["content_block"]["text"]})
              {[chunk], :in_text}

            %{"type" => "tool_use"} = content ->
              adjusted_content = %{
                "name" => content["name"],
                "arguments" => "",
                "id" => content["id"]
              }

              response_handler_fn.({:function_call, adjusted_content})
              {[chunk], :in_function}

            _ ->
              {:ignore}
          end

        "content_block_stop" ->
          case state do
            :in_text ->
              response_handler_fn.({:tokens_finished})
              {[], nil}

            :in_function ->
              response_handler_fn.({:function_call_finished})
              {[], nil}
          end

        "content_block_delta" ->
          case chunk["delta"] do
            %{"type" => "text_delta"} ->
              response_handler_fn.({:tokens_received, chunk["delta"]["text"]})
              {[chunk], state}

            %{"type" => "input_json_delta"} = content ->
              adjusted_content = %{
                "arguments" => content["partial_json"]
              }

              response_handler_fn.({:function_call, adjusted_content})
              {[chunk], state}

            _ ->
              {[], state}
          end

        _ ->
          {[], state}
      end
    end)
    |> Stream.run()
  end

  defp create_client(variable_name) do
    read_var(variable_name)
    |> Anthropix.init(
      receive_timeout: System.get_env("ANTHROPIC_RECV_TIMEOUT", "60000") |> String.to_integer()
    )
  end

  defp encode_functions(functions) do
    Enum.map(functions, fn function ->
      %{
        name: function.name,
        description: function.description,
        # Notice the "input_schema" key here, unique to Claude
        input_schema: function.parameters
      }
    end)
  end

  # Encodes messages for Claude, converting system messages to user messages
  # and function results to tool results.  This requirese a multi-step transformation
  # to ensure the messages are in the correct format for Claude.
  defp encode_messages(messages) do
    {translated, _tool} =
      Enum.map(messages, fn message ->
        case message.role do
          :system ->
            %{message | role: :user}

          :function ->
            %{
              role: :tool_result,
              name: nil,
              content: [
                %{
                  type: "tool_result",
                  tool_use_id: message.id,
                  content: Jason.encode!(message.content)
                }
              ],
              tool: %{
                type: "tool_use",
                id: message.id,
                name: message.name,
                input: message.input
              }
            }

          _ ->
            message
        end
      end)
      |> Enum.reverse()
      |> Enum.reduce({[], nil}, fn message, {all, tool} ->
        case message.role do
          :tool_result ->
            tool = message.tool
            message = Map.delete(message, :tool) |> Map.put(:role, :user)
            {[message | all], tool}

          _other ->
            case tool do
              nil ->
                {[message | all], nil}

              tool ->
                # We adjust the content of what was the :assistant message preceeding
                # the function call result - making it an array

                message =
                  Map.put(message, :content, [
                    %{
                      type: "text",
                      text: message.content
                    },
                    tool
                  ])

                {[message | all], nil}
            end
        end
      end)

    Enum.map(translated, fn message ->
      case message.name do
        nil ->
          %{role: message.role |> Atom.to_string(), content: message.content}

        _ ->
          %{role: message.role |> Atom.to_string(), content: message.content, name: message.name}
      end
    end)
  end

  defp read_var(nil), do: ""

  defp read_var(key) do
    System.get_env(key)
  end
end
