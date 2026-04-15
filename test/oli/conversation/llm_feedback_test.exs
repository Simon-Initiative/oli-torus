defmodule Oli.Conversation.LLMFeedbackTest do
  use Oli.DataCase, async: true

  alias Oli.Conversation.LLMFeedback
  alias Oli.Delivery.Attempts.Core.StudentInput

  describe "generate/5" do
    test "returns ok with feedback text when service config is available (null provider)" do
      # With a DataCase sandbox, the global null-provider service config is available.
      # The null provider returns a canned string, validating the full pipeline runs.
      result =
        LLMFeedback.generate(
          "Help the student",
          "student typed something",
          "non-existent-guid",
          -1,
          -1
        )

      assert {:ok, _text} = result
    end
  end

  describe "find_llm_feedback_prompt/1" do
    test "returns prompt from activation point action with kind feedback" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "feedback", "prompt" => "Guide the student"}
                }
              ]
            }
          }
        ]
      }

      assert "Guide the student" == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns nil when no activation point actions exist" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{"type" => "feedback", "params" => %{"feedback" => %{"id" => "f1"}}}
              ]
            }
          }
        ]
      }

      assert nil == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns nil for activation point with kind dot (not feedback)" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "dot", "prompt" => "Chat prompt"}
                }
              ]
            }
          }
        ]
      }

      assert nil == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns nil for activation point without kind" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"prompt" => "Some prompt"}
                }
              ]
            }
          }
        ]
      }

      assert nil == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns nil for empty prompt" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "feedback", "prompt" => ""}
                }
              ]
            }
          }
        ]
      }

      assert nil == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns first feedback prompt when multiple exist" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "feedback", "prompt" => "First prompt"}
                },
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "feedback", "prompt" => "Second prompt"}
                }
              ]
            }
          }
        ]
      }

      assert "First prompt" == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "finds feedback in second result when first has no feedback actions" do
      evaluations = %{
        "results" => [
          %{
            "params" => %{
              "actions" => [
                %{"type" => "navigation", "params" => %{"target" => "next"}}
              ]
            }
          },
          %{
            "params" => %{
              "actions" => [
                %{
                  "type" => "activationPoint",
                  "params" => %{"kind" => "feedback", "prompt" => "Found it"}
                }
              ]
            }
          }
        ]
      }

      assert "Found it" == LLMFeedback.find_llm_feedback_prompt(evaluations)
    end

    test "returns nil for empty results list" do
      assert nil == LLMFeedback.find_llm_feedback_prompt(%{"results" => []})
    end

    test "returns nil for nil input" do
      assert nil == LLMFeedback.find_llm_feedback_prompt(nil)
    end

    test "returns nil for non-map input" do
      assert nil == LLMFeedback.find_llm_feedback_prompt("not a map")
    end

    test "returns nil when results is not a list" do
      assert nil == LLMFeedback.find_llm_feedback_prompt(%{"results" => "invalid"})
    end
  end

  describe "extract_student_input/1" do
    test "extracts string value from student input" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{"answer" => %{"value" => "The mitochondria is the powerhouse"}}
          }
        }
      ]

      assert "The mitochondria is the powerhouse" ==
               LLMFeedback.extract_student_input(part_inputs)
    end

    test "extracts multiple values from single input joined by semicolons" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{
              "field1" => %{"value" => "answer one"},
              "field2" => %{"value" => "answer two"}
            }
          }
        }
      ]

      result = LLMFeedback.extract_student_input(part_inputs)
      assert result =~ "answer one"
      assert result =~ "answer two"
      assert result =~ ";"
    end

    test "extracts inputs from multiple parts joined by newlines" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{"q1" => %{"value" => "First answer"}}
          }
        },
        %{
          input: %StudentInput{
            input: %{"q2" => %{"value" => "Second answer"}}
          }
        }
      ]

      result = LLMFeedback.extract_student_input(part_inputs)
      assert result =~ "First answer"
      assert result =~ "Second answer"
      assert result =~ "\n"
    end

    test "inspects non-string values" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{"answer" => %{"value" => 42}}
          }
        }
      ]

      assert "42" == LLMFeedback.extract_student_input(part_inputs)
    end

    test "skips entries without value key" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{"answer" => %{"text" => "no value key here"}}
          }
        }
      ]

      assert "" == LLMFeedback.extract_student_input(part_inputs)
    end

    test "skips non-StudentInput entries" do
      part_inputs = [
        %{input: "just a string"},
        %{
          input: %StudentInput{
            input: %{"q1" => %{"value" => "valid"}}
          }
        }
      ]

      assert "valid" == LLMFeedback.extract_student_input(part_inputs)
    end

    test "returns empty string for empty list" do
      assert "" == LLMFeedback.extract_student_input([])
    end

    test "returns empty string for nil" do
      assert "" == LLMFeedback.extract_student_input(nil)
    end

    test "returns empty string for non-list input" do
      assert "" == LLMFeedback.extract_student_input("not a list")
    end

    test "filters out empty string values after extraction" do
      part_inputs = [
        %{
          input: %StudentInput{
            input: %{"q1" => %{"value" => ""}}
          }
        },
        %{
          input: %StudentInput{
            input: %{"q2" => %{"value" => "actual answer"}}
          }
        }
      ]

      assert "actual answer" == LLMFeedback.extract_student_input(part_inputs)
    end
  end
end
