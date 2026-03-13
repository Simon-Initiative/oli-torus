defmodule Oli.GenAI.Completions.OpenAICompliantProviderTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.OpenAICompliantProvider

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
  end
end
