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
    client = create_client(registered_model)

    case Anthropix.chat(client,
           model: model,
           messages: encode_messages(messages),
           tools: encode_functions(functions)
         ) do
      {:ok, response} ->
        {:ok, normalize_response(response)}

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
    client = create_client(registered_model)

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

  defp create_client(registered_model) do
    Anthropix.init(
      registered_model.api_key,
      receive_timeout: registered_model.recv_timeout
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

  # Normalize Claude response to consistent format (OpenAI-style)
  defp normalize_response(response) do
    # Claude returns in format: %{"content" => [...], "role" => "assistant", ...}
    # Convert to OpenAI-style format: %{"choices" => [%{"message" => ...}], ...}

    content = Map.get(response, "content", [])

    # Check if there are any tool_use blocks
    tool_calls =
      Enum.filter(content, fn item ->
        Map.get(item, "type") == "tool_use"
      end)

    message =
      if Enum.empty?(tool_calls) do
        # No tool calls, extract text content
        text_content =
          Enum.find_value(content, "", fn item ->
            case item do
              %{"type" => "text", "text" => text} -> text
              _ -> nil
            end
          end)

        %{
          "role" => "assistant",
          "content" => text_content
        }
      else
        # Convert tool_use blocks to OpenAI-style tool_calls
        openai_tool_calls =
          Enum.map(tool_calls, fn tool_use ->
            %{
              "id" => Map.get(tool_use, "id", "call_" <> Ecto.UUID.generate()),
              "type" => "function",
              "function" => %{
                "name" => Map.get(tool_use, "name"),
                "arguments" => Jason.encode!(Map.get(tool_use, "input", %{}))
              }
            }
          end)

        %{
          "role" => "assistant",
          "content" => nil,
          "tool_calls" => openai_tool_calls
        }
      end

    # Return in OpenAI format
    %{
      "choices" => [
        %{
          "index" => 0,
          "message" => message,
          "finish_reason" => if(Enum.empty?(tool_calls), do: "stop", else: "tool_calls")
        }
      ],
      "usage" => Map.get(response, "usage", %{})
    }
  end
end
