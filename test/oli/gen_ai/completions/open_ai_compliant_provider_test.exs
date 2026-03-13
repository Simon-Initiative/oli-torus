defmodule Oli.GenAI.Completions.OpenAICompliantProviderTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.Function
  alias Oli.GenAI.Completions.OpenAICompliantProvider
  alias HTTPoison.{AsyncEnd, Error}

  describe "decode_stream_chunk/2" do
    test "buffers partial SSE payloads until a full event is available" do
      {data, buffer} =
        OpenAICompliantProvider.decode_stream_chunk(
          "",
          "data: {\"id\":\"chatcmpl-DJ3cA"
        )

      assert data == []
      assert buffer == "data: {\"id\":\"chatcmpl-DJ3cA"

      {data, buffer} =
        OpenAICompliantProvider.decode_stream_chunk(
          buffer,
          "\",\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\n"
        )

      assert buffer == ""

      assert data == [
               %{
                 "id" => "chatcmpl-DJ3cA",
                 "choices" => [%{"delta" => %{"content" => "Hi"}}]
               }
             ]
    end

    test "ignores done sentinels and decodes multiple events from one chunk" do
      chunk = """
      data: {"choices":[{"delta":{"content":"Hi"}}]}

      data: [DONE]

      data: {"choices":[{"finish_reason":"stop"}]}

      """

      {data, buffer} = OpenAICompliantProvider.decode_stream_chunk("", chunk)

      assert buffer == ""

      assert data == [
               %{"choices" => [%{"delta" => %{"content" => "Hi"}}]},
               %{"choices" => [%{"finish_reason" => "stop"}]}
             ]
    end

    test "accepts SSE data lines without a separating space" do
      {data, buffer} =
        OpenAICompliantProvider.decode_stream_chunk(
          "",
          "data:{\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\n"
        )

      assert buffer == ""
      assert data == [%{"choices" => [%{"delta" => %{"content" => "Hi"}}]}]
    end
  end

  describe "encode_messages/1" do
    test "expands function results into assistant tool_calls plus tool response" do
      messages = [
        %Oli.GenAI.Completions.Message{
          role: :user,
          content: "How am I doing?",
          token_length: nil,
          name: nil,
          id: nil,
          input: nil
        },
        %Oli.GenAI.Completions.Message{
          role: :function,
          content: "{\"result\":[]}",
          token_length: nil,
          name: "up_next",
          id: "call_test123",
          input: %{"current_user_id" => 104, "section_id" => 1}
        }
      ]

      assert OpenAICompliantProvider.encode_messages(messages) == [
               %{role: :user, content: "How am I doing?"},
               %{
                 role: "assistant",
                 tool_calls: [
                   %{
                     id: "call_test123",
                     type: "function",
                     function: %{
                       name: "up_next",
                       arguments: "{\"current_user_id\":104,\"section_id\":1}"
                     }
                   }
                 ]
               },
               %{
                 role: "tool",
                 tool_call_id: "call_test123",
                 content: "{\"result\":[]}"
               }
             ]
    end
  end

  describe "completion_params/4" do
    test "uses tools param when functions are provided" do
      messages = [
        %Oli.GenAI.Completions.Message{
          role: :user,
          content: "Hello",
          token_length: nil,
          name: nil,
          id: nil,
          input: nil
        }
      ]

      functions = [
        %Function{
          name: "avg_score_for",
          description: "Average score",
          parameters: %{"type" => "object"}
        }
      ]

      params = OpenAICompliantProvider.completion_params("gpt-x", messages, functions)

      assert Keyword.has_key?(params, :tools)
      refute Keyword.has_key?(params, :functions)
    end

    test "encodes tools in chat-completions schema format" do
      messages = [
        %Oli.GenAI.Completions.Message{
          role: :user,
          content: "Hello",
          token_length: nil,
          name: nil,
          id: nil,
          input: nil
        }
      ]

      functions = [
        %Function{
          name: "avg_score_for",
          description: "Average score",
          parameters: %{"type" => "object"}
        }
      ]

      params = OpenAICompliantProvider.completion_params("gpt-x", messages, functions)

      assert Keyword.get(params, :tools) == [
               %{
                 type: "function",
                 function: %{
                   name: "avg_score_for",
                   description: "Average score",
                   parameters: %{"type" => "object"}
                 }
               }
             ]
    end

    test "uses tools param when messages contain tool-calling context" do
      messages = [
        %Oli.GenAI.Completions.Message{
          role: :user,
          content: "How am I doing?",
          token_length: nil,
          name: nil,
          id: nil,
          input: nil
        },
        %Oli.GenAI.Completions.Message{
          role: :function,
          content: "{\"result\":[]}",
          token_length: nil,
          name: "avg_score_for",
          id: "call_test123",
          input: %{"current_user_id" => 104, "section_id" => 1}
        }
      ]

      functions = [
        %Function{
          name: "avg_score_for",
          description: "Average score",
          parameters: %{"type" => "object"}
        }
      ]

      params =
        OpenAICompliantProvider.completion_params("gpt-x", messages, functions, stream: true)

      assert Keyword.has_key?(params, :tools)
      refute Keyword.has_key?(params, :functions)
      assert Keyword.get(params, :stream) == true
    end

    test "does not include tools when no functions are provided" do
      messages = [
        %Oli.GenAI.Completions.Message{
          role: :user,
          content: "Hello",
          token_length: nil,
          name: nil,
          id: nil,
          input: nil
        }
      ]

      params = OpenAICompliantProvider.completion_params("gpt-x", messages, [])

      refute Keyword.has_key?(params, :tools)
      refute Keyword.has_key?(params, :functions)
    end
  end

  describe "process_stream_chunk/1" do
    test "decodes modern tool_calls streaming deltas" do
      chunk = %{
        "choices" => [
          %{
            "delta" => %{
              "tool_calls" => [
                %{
                  "id" => "call_test123",
                  "function" => %{
                    "name" => "up_next",
                    "arguments" => "{\"section_id\":1}"
                  }
                }
              ]
            }
          }
        ]
      }

      assert OpenAICompliantProvider.process_stream_chunk(chunk) ==
               {:function_call,
                %{
                  "id" => "call_test123",
                  "name" => "up_next",
                  "arguments" => "{\"section_id\":1}"
                }}
    end

    test "treats tool_calls finish reasons as function completion" do
      chunk = %{"choices" => [%{"finish_reason" => "tool_calls"}]}

      assert OpenAICompliantProvider.process_stream_chunk(chunk) == {:function_call_finished}
    end

    test "treats legacy function_call deltas as errors" do
      chunk = %{"choices" => [%{"delta" => %{"function_call" => %{"name" => "legacy"}}}]}

      assert OpenAICompliantProvider.process_stream_chunk(chunk) == {:error}
    end

    test "treats legacy function_call finish reasons as errors" do
      chunk = %{"choices" => [%{"finish_reason" => "function_call"}]}

      assert OpenAICompliantProvider.process_stream_chunk(chunk) == {:error}
    end
  end

  describe "process_async_stream_message/2" do
    test "emits an error chunk and halts on mid-stream transport errors" do
      message = %Error{id: make_ref(), reason: :closed}

      assert OpenAICompliantProvider.process_async_stream_message(message, "") ==
               {:emit_and_halt, [%{"choices" => [], "reason" => :closed, "status" => :error}]}
    end

    test "emits buffered content when the final SSE event arrives without a delimiter" do
      message = %AsyncEnd{id: make_ref()}
      buffer = "data: {\"choices\":[{\"finish_reason\":\"stop\"}]}"

      assert OpenAICompliantProvider.process_async_stream_message(message, buffer) ==
               {:emit_and_halt, [%{"choices" => [%{"finish_reason" => "stop"}]}]}
    end

    test "emits an error chunk when EOF arrives with an incomplete buffered event" do
      message = %AsyncEnd{id: make_ref()}
      buffer = "data: {\"choices\":[{\"delta\":{\"content\":\"Hi"

      assert OpenAICompliantProvider.process_async_stream_message(message, buffer) ==
               {:emit_and_halt,
                [%{"choices" => [], "reason" => :incomplete_sse_event, "status" => :error}]}
    end

    test "treats a final done sentinel without a delimiter as a clean halt" do
      message = %AsyncEnd{id: make_ref()}

      assert OpenAICompliantProvider.process_async_stream_message(message, "data: [DONE]") ==
               {:halt}
    end
  end
end
