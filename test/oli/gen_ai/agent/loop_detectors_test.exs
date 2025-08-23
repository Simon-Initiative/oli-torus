defmodule Oli.GenAI.Agent.LoopDetectorsTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Agent.LoopDetectors.{
    ConsecutiveIdentical,
    AlternatingPattern,
    RepeatedIdentical
  }

  describe "ConsecutiveIdentical.detect/1" do
    test "detects consecutive identical tool calls" do
      steps = [
        %{action: %{type: "tool", name: "search", args: %{query: "test"}}},
        %{action: %{type: "tool", name: "search", args: %{query: "test"}}},
        %{action: %{type: "tool", name: "other", args: %{}}},
        %{action: %{type: "tool", name: "final", args: %{}}}
      ]

      assert ConsecutiveIdentical.detect(steps)
    end

    test "returns false when no consecutive identical calls" do
      steps = [
        %{action: %{type: "tool", name: "search", args: %{query: "test1"}}},
        %{action: %{type: "tool", name: "fetch", args: %{id: 1}}},
        %{action: %{type: "tool", name: "search", args: %{query: "test2"}}},
        %{action: %{type: "tool", name: "fetch", args: %{id: 2}}}
      ]

      refute ConsecutiveIdentical.detect(steps)
    end

    test "handles empty or short lists" do
      refute ConsecutiveIdentical.detect([])
      refute ConsecutiveIdentical.detect([%{action: %{type: "tool", name: "test", args: %{}}}])
    end

    test "handles non-list input" do
      refute ConsecutiveIdentical.detect(nil)
      refute ConsecutiveIdentical.detect("not a list")
    end
  end

  describe "AlternatingPattern.detect/1" do
    test "detects A-B-A-B pattern" do
      steps = [
        %{action: %{type: "tool", name: "B", args: %{id: 2}}},
        %{action: %{type: "tool", name: "A", args: %{id: 1}}},
        %{action: %{type: "tool", name: "B", args: %{id: 2}}},
        %{action: %{type: "tool", name: "A", args: %{id: 1}}}
      ]

      assert AlternatingPattern.detect(steps)
    end

    test "returns false when pattern doesn't alternate" do
      steps = [
        %{action: %{type: "tool", name: "A", args: %{id: 1}}},
        %{action: %{type: "tool", name: "A", args: %{id: 1}}},
        %{action: %{type: "tool", name: "B", args: %{id: 2}}},
        %{action: %{type: "tool", name: "B", args: %{id: 2}}}
      ]

      refute AlternatingPattern.detect(steps)
    end

    test "returns false when steps don't match pattern positions" do
      steps = [
        %{action: %{type: "tool", name: "A", args: %{id: 1}}},
        %{action: %{type: "tool", name: "B", args: %{id: 2}}},
        %{action: %{type: "tool", name: "C", args: %{id: 3}}},
        %{action: %{type: "tool", name: "D", args: %{id: 4}}}
      ]

      refute AlternatingPattern.detect(steps)
    end

    test "requires exactly 4 steps" do
      steps = [
        %{action: %{type: "tool", name: "A", args: %{}}},
        %{action: %{type: "tool", name: "B", args: %{}}},
        %{action: %{type: "tool", name: "A", args: %{}}}
      ]

      refute AlternatingPattern.detect(steps)
    end

    test "handles non-list input" do
      refute AlternatingPattern.detect(nil)
      refute AlternatingPattern.detect(%{})
    end
  end

  describe "RepeatedIdentical.detect/1" do
    test "detects when same tool called 3+ times" do
      steps = [
        %{action: %{type: "tool", name: "fetch", args: %{url: "same"}}},
        %{action: %{type: "message", content: "thinking"}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "same"}}},
        %{action: %{type: "message", content: "still thinking"}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "same"}}},
        %{action: %{type: "tool", name: "other", args: %{}}}
      ]

      assert RepeatedIdentical.detect(steps)
    end

    test "returns false when same tool called less than 3 times" do
      steps = [
        %{action: %{type: "tool", name: "fetch", args: %{url: "same"}}},
        %{action: %{type: "message", content: "thinking"}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "same"}}},
        %{action: %{type: "tool", name: "other", args: %{}}}
      ]

      refute RepeatedIdentical.detect(steps)
    end

    test "distinguishes between different arguments" do
      steps = [
        %{action: %{type: "tool", name: "fetch", args: %{url: "url1"}}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "url2"}}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "url3"}}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "url4"}}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "url5"}}},
        %{action: %{type: "tool", name: "fetch", args: %{url: "url6"}}}
      ]

      refute RepeatedIdentical.detect(steps)
    end

    test "only considers tool actions" do
      steps = [
        %{action: %{type: "message", content: "same"}},
        %{action: %{type: "message", content: "same"}},
        %{action: %{type: "message", content: "same"}},
        %{action: %{type: "message", content: "same"}},
        %{action: %{type: "message", content: "same"}},
        %{action: %{type: "message", content: "same"}}
      ]

      refute RepeatedIdentical.detect(steps)
    end

    test "handles empty or short lists" do
      refute RepeatedIdentical.detect([])
      refute RepeatedIdentical.detect([%{action: %{type: "tool", name: "test", args: %{}}}])
    end

    test "handles non-list input" do
      refute RepeatedIdentical.detect(nil)
      refute RepeatedIdentical.detect("not a list")
    end
  end
end
