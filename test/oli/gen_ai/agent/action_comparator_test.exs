defmodule Oli.GenAI.Agent.ActionComparatorTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Agent.ActionComparator

  describe "identical?/2" do
    test "identifies identical tool actions with same name and args" do
      action1 = %{type: "tool", name: "search", args: %{query: "test"}}
      action2 = %{type: "tool", name: "search", args: %{query: "test"}}

      assert ActionComparator.identical?(action1, action2)
    end

    test "identifies different tool actions with different names" do
      action1 = %{type: "tool", name: "search", args: %{query: "test"}}
      action2 = %{type: "tool", name: "fetch", args: %{query: "test"}}

      refute ActionComparator.identical?(action1, action2)
    end

    test "identifies different tool actions with different args" do
      action1 = %{type: "tool", name: "search", args: %{query: "test1"}}
      action2 = %{type: "tool", name: "search", args: %{query: "test2"}}

      refute ActionComparator.identical?(action1, action2)
    end

    test "ignores large JSON strings when comparing" do
      large_json1 = "{" <> String.duplicate("\"data\": \"value\",", 50) <> "}"
      large_json2 = "{" <> String.duplicate("\"other\": \"different\",", 50) <> "}"

      action1 = %{type: "tool", name: "process", args: %{data: large_json1, id: 1}}
      action2 = %{type: "tool", name: "process", args: %{data: large_json2, id: 1}}

      assert ActionComparator.identical?(action1, action2)
    end

    test "compares message actions by first 50 chars" do
      action1 = %{
        type: "message",
        content: "This is a long message that goes beyond 50 characters and should be truncated"
      }

      action2 = %{
        type: "message",
        content: "This is a long message that goes beyond 50 characters with different ending"
      }

      assert ActionComparator.identical?(action1, action2)
    end

    test "identifies different message actions with different prefixes" do
      action1 = %{type: "message", content: "First message"}
      action2 = %{type: "message", content: "Second message"}

      refute ActionComparator.identical?(action1, action2)
    end
  end

  describe "normalize/1" do
    test "normalizes tool actions to tuple format" do
      action = %{type: "tool", name: "search", args: %{query: "test"}}

      assert {:tool, "search", %{query: "test"}} = ActionComparator.normalize(action)
    end

    test "removes large JSON from tool args during normalization" do
      large_json = String.duplicate("{\"data\": \"value\"}", 20)
      action = %{type: "tool", name: "process", args: %{data: large_json, id: 1}}

      {:tool, "process", normalized_args} = ActionComparator.normalize(action)

      assert normalized_args == %{id: 1}
      refute Map.has_key?(normalized_args, :data)
    end

    test "normalizes message actions with content truncation" do
      action = %{
        type: "message",
        content: "This is a very long message that should be truncated for comparison purposes"
      }

      {:message, content} = ActionComparator.normalize(action)

      assert String.length(content) == 50
      assert String.starts_with?(content, "This is a very long message")
    end

    test "handles non-string content in messages" do
      action = %{type: "message", content: %{nested: "data"}}

      assert {:message, %{nested: "data"}} = ActionComparator.normalize(action)
    end

    test "normalizes other action types generically" do
      action = %{type: "custom", foo: "bar", baz: "qux"}

      assert {"custom", %{foo: "bar", baz: "qux"}} = ActionComparator.normalize(action)
    end

    test "returns non-map actions unchanged" do
      assert ActionComparator.normalize("string") == "string"
      assert ActionComparator.normalize(nil) == nil
      assert ActionComparator.normalize(123) == 123
    end
  end

  describe "key_args_match?/2" do
    test "matches identical map arguments" do
      args1 = %{query: "test", limit: 10}
      args2 = %{query: "test", limit: 10}

      assert ActionComparator.key_args_match?(args1, args2)
    end

    test "does not match different map arguments" do
      args1 = %{query: "test1", limit: 10}
      args2 = %{query: "test2", limit: 10}

      refute ActionComparator.key_args_match?(args1, args2)
    end

    test "ignores large JSON values when matching" do
      large_json1 = Jason.encode!(%{data: List.duplicate("value", 100)})
      large_json2 = Jason.encode!(%{data: List.duplicate("different", 100)})

      args1 = %{id: 1, payload: large_json1}
      args2 = %{id: 1, payload: large_json2}

      assert ActionComparator.key_args_match?(args1, args2)
    end

    test "matches non-map arguments directly" do
      assert ActionComparator.key_args_match?("string", "string")
      assert ActionComparator.key_args_match?(123, 123)
      refute ActionComparator.key_args_match?("string1", "string2")
      refute ActionComparator.key_args_match?(123, 456)
    end

    test "handles nil arguments" do
      assert ActionComparator.key_args_match?(nil, nil)
      refute ActionComparator.key_args_match?(nil, "value")
      refute ActionComparator.key_args_match?("value", nil)
    end
  end

  describe "is_large_json?/1" do
    test "identifies large JSON strings" do
      large_json = Jason.encode!(%{data: List.duplicate("value", 100)})

      assert ActionComparator.is_large_json?(large_json)
    end

    test "identifies JSON-like strings using heuristic" do
      json_like = "{" <> String.duplicate("data", 60) <> "}"

      assert ActionComparator.is_large_json?(json_like)
    end

    test "rejects small strings" do
      small_json = Jason.encode!(%{key: "value"})

      refute ActionComparator.is_large_json?(small_json)
    end

    test "rejects non-JSON strings" do
      large_string = String.duplicate("not json", 50)

      refute ActionComparator.is_large_json?(large_string)
    end

    test "handles non-string values" do
      refute ActionComparator.is_large_json?(123)
      refute ActionComparator.is_large_json?(nil)
      refute ActionComparator.is_large_json?(%{})
      refute ActionComparator.is_large_json?([])
    end
  end
end
