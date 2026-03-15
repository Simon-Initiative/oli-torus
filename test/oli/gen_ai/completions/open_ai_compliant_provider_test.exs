defmodule Oli.GenAI.Completions.OpenAICompliantProviderTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.OpenAICompliantProvider

  describe "process_stream_chunk/1" do
    test "ignores role-only delta chunks" do
      assert :ignore ==
               OpenAICompliantProvider.process_stream_chunk(%{
                 "choices" => [%{"delta" => %{"role" => "assistant"}}]
               })
    end

    test "ignores empty delta chunks" do
      assert :ignore ==
               OpenAICompliantProvider.process_stream_chunk(%{
                 "choices" => [%{"delta" => %{}}]
               })
    end

    test "returns content tokens for content delta chunks" do
      assert {:tokens_received, "hello"} ==
               OpenAICompliantProvider.process_stream_chunk(%{
                 "choices" => [%{"delta" => %{"content" => "hello"}}]
               })
    end
  end
end
