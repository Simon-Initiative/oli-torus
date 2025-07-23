defmodule Oli.GenAI.Completions.NullProviderTest do

  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.NullProvider
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.Completions.RegisteredModel

  describe "generate/4" do
    test "returns an error tuple" do
      messages = [Message.new(:system, "Hello")]
      functions = []
      registered_model = %RegisteredModel{name: "test_model", provider: :null}

      assert NullProvider.generate(messages, functions, registered_model, []) == {:ok,  "This is a null provider. No generation performed."}
    end
  end

  describe "stream/5" do
    test "returns an error tuple" do
      messages = [Message.new(:system, "Hello")]
      functions = []
      registered_model = %RegisteredModel{name: "test_model", provider: :null}
      stream_fn = fn _chunk ->
        :ok
      end

      assert NullProvider.stream(messages, functions, registered_model, stream_fn, []) ==
        [{"This", 0}, {"is", 1}, {"a", 2}, {"null", 3}, {"provider.", 4}, {"No", 5}, {"generation", 6}, {"performed.", 7}, {"STOP", 8}]
    end
  end
end
