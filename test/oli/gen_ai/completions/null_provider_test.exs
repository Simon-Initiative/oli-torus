defmodule Oli.GenAI.Completions.NullProviderTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.NullProvider
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.Completions.RegisteredModel

  describe "generate/4" do
    test "that it generates the static text" do
      messages = [Message.new(:system, "Hello")]
      functions = []
      registered_model = %RegisteredModel{name: "test_model", provider: :null}

      assert NullProvider.generate(messages, functions, registered_model) ==
               {:ok, "This is a null provider. No generation performed."}
    end
  end

  describe "stream/5" do
    test "that it streams the static test" do
      messages = [Message.new(:system, "Hello")]
      functions = []
      registered_model = %RegisteredModel{name: "test_model", provider: :null}

      stream_fn = fn _chunk ->
        :ok
      end

      assert NullProvider.stream(messages, functions, registered_model, stream_fn) == :ok
    end
  end
end
