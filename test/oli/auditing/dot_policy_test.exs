defmodule Oli.Auditing.DotPolicyTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.DotPolicy

  doctest DotPolicy

  describe "triggers/1" do
    test "projects page, group, and content-block triggers of a page" do
      content = %{
        "trigger" => %{"id" => "t0", "trigger_type" => "page", "prompt" => "Greet"},
        "model" => [
          %{
            "type" => "group",
            "id" => "g1",
            "trigger" => %{"id" => "t1", "trigger_type" => "group", "prompt" => "Summarize"},
            "children" => [
              %{
                "type" => "content",
                "id" => "c1",
                "children" => [
                  %{
                    "type" => "p",
                    "children" => [
                      %{
                        "type" => "trigger",
                        "id" => "t2",
                        "trigger_type" => "content",
                        "prompt" => "Explain"
                      }
                    ]
                  }
                ]
              }
            ]
          },
          %{"type" => "selection", "id" => "s1", "count" => 1}
        ]
      }

      assert DotPolicy.triggers(content) == [
               %{"path" => "content:t2", "trigger_type" => "content", "prompt" => "Explain"},
               %{"path" => "group:g1", "trigger_type" => "group", "prompt" => "Summarize"},
               %{"path" => "page", "trigger_type" => "page", "prompt" => "Greet"}
             ]
    end

    test "projects activity part triggers" do
      content = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "triggers" => [
                %{"id" => "a", "trigger_type" => "hint", "prompt" => "Hint", "ref_id" => 1},
                %{"id" => "b", "trigger_type" => "correct_answer", "prompt" => "Well done"}
              ]
            }
          ]
        }
      }

      assert DotPolicy.triggers(content) == [
               %{"path" => "part:1:a", "trigger_type" => "hint", "prompt" => "Hint"},
               %{
                 "path" => "part:1:b",
                 "trigger_type" => "correct_answer",
                 "prompt" => "Well done"
               }
             ]
    end

    test "projects adaptive trigger parts and activation points" do
      content = %{
        "partsLayout" => [
          %{"id" => "ai-1", "type" => "janus-ai-trigger", "custom" => %{"prompt" => "Ask"}},
          %{
            "id" => "img-1",
            "type" => "janus-image",
            "custom" => %{"enableAiTrigger" => true, "aiTriggerPrompt" => "Describe"}
          },
          %{"id" => "img-2", "type" => "janus-image", "custom" => %{}}
        ],
        "authoring" => %{
          "parts" => [%{"id" => "ai-1", "type" => "janus-ai-trigger"}],
          "rules" => [
            %{
              "event" => %{
                "type" => "r1.correct",
                "params" => %{
                  "actions" => [
                    %{"type" => "feedback", "params" => %{}},
                    %{
                      "type" => "activationPoint",
                      "params" => %{"prompt" => "Why?", "kind" => "dot"}
                    }
                  ]
                }
              }
            }
          ]
        }
      }

      assert DotPolicy.triggers(content) == [
               %{"path" => "part:ai-1", "trigger_type" => "janus-ai-trigger", "prompt" => "Ask"},
               %{"path" => "part:img-1", "trigger_type" => "janus-image", "prompt" => "Describe"},
               %{
                 "path" => "rule:r1.correct:1",
                 "trigger_type" => "activation_point:dot",
                 "prompt" => "Why?"
               }
             ]
    end

    test "cuts prompts longer than 2,000 characters" do
      prompt = String.duplicate("a", 2_001)
      content = %{"trigger" => %{"trigger_type" => "page", "prompt" => prompt}}

      assert [%{"prompt" => recorded, "prompt_truncated" => true}] = DotPolicy.triggers(content)
      assert String.length(recorded) == 2_000
    end

    test "returns no triggers for content without any" do
      assert DotPolicy.triggers(nil) == []
      assert DotPolicy.triggers(%{"model" => []}) == []
    end
  end

  describe "changes/2" do
    test "records only the triggers that were added, removed, or changed" do
      kept = %{"path" => "page", "trigger_type" => "page", "prompt" => "Greet"}
      edited = %{"path" => "group:g1", "trigger_type" => "group", "prompt" => "Old"}
      removed = %{"path" => "content:t2", "trigger_type" => "content", "prompt" => "Gone"}
      added = %{"path" => "content:t3", "trigger_type" => "content", "prompt" => "New"}

      assert DotPolicy.changes([kept, edited, removed], [
               kept,
               %{edited | "prompt" => "New"},
               added
             ]) ==
               %{
                 "triggers" => %{
                   "operation" => "set",
                   "before" => [removed, edited],
                   "after" => [added, %{edited | "prompt" => "New"}]
                 }
               }
    end

    test "records nothing when the triggers are the same" do
      triggers = [%{"path" => "page", "trigger_type" => "page", "prompt" => "Greet"}]
      assert DotPolicy.changes(triggers, triggers) == %{}
    end
  end
end
