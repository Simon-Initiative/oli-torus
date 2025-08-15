defmodule Oli.ValidationTest do
  use ExUnit.Case, async: true

  alias Oli.Validation

  describe "validate_activity/1" do
    test "validates a simple activity with valid content" do
      activity = %{
        "stem" => %{
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "What is 2 + 2?"}]
            }
          ]
        },
        "choices" => [
          %{
            "id" => "choice_1",
            "content" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "3"}]
              }
            ]
          },
          %{
            "id" => "choice_2",
            "content" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "4"}]
              }
            ]
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "hints" => [
                %{
                  "id" => "hint_1",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Think about basic arithmetic"}]
                    }
                  ]
                }
              ],
              "feedback" => [
                %{
                  "id" => "feedback_1",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! 2 + 2 = 4"}]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }

      assert {:ok, %Oli.Activities.Model{}} = Validation.validate_activity(activity)
    end

    test "validates activity without optional content fields" do
      activity = %{
        "authoring" => %{
          "parts" => []
        }
      }

      assert {:ok, %Oli.Activities.Model{}} = Validation.validate_activity(activity)
    end

    test "validates activity with complex content elements" do
      activity = %{
        "stem" => %{
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Consider this "}]
            },
            %{
              "type" => "img",
              "src" => "/images/example.png",
              "alt" => "Example image"
            },
            %{
              "type" => "table",
              "children" => [
                %{
                  "type" => "tr",
                  "children" => [
                    %{
                      "type" => "td",
                      "children" => [
                        %{
                          "type" => "p",
                          "children" => [%{"text" => "Cell content"}]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }

      assert {:ok, %Oli.Activities.Model{}} = Validation.validate_activity(activity)
    end

    test "rejects non-map input" do
      assert {:error, "Activity must be a map"} = Validation.validate_activity("not a map")
      assert {:error, "Activity must be a map"} = Validation.validate_activity(nil)
      assert {:error, "Activity must be a map"} = Validation.validate_activity(123)
    end

    test "rejects invalid content schema in stem" do
      activity = %{
        "stem" => %{
          "content" => [
            %{
              "type" => "invalid_type",
              "children" => [%{"text" => "Invalid content"}]
            }
          ]
        }
      }

      assert {:error, {"stem.content[0]", _errors}} = Validation.validate_activity(activity)
    end

    test "rejects invalid content schema in choices" do
      activity = %{
        "choices" => [
          %{
            "id" => "choice_1",
            "content" => [
              %{
                "type" => "p",
                "children" => "should be a list, not string"
              }
            ]
          }
        ]
      }

      assert {:error, {"choices[0].content[0]", _errors}} = Validation.validate_activity(activity)
    end

    test "rejects invalid content schema in hints" do
      activity = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "hints" => [
                %{
                  "id" => "hint_1",
                  "content" => [
                    %{
                      "type" => "p"
                      # missing required children field
                    }
                  ]
                }
              ]
            }
          ]
        }
      }

      assert {:error, {"authoring.parts[0].hints[0].content[0]", _errors}} = 
        Validation.validate_activity(activity)
    end

    test "rejects invalid content schema in feedback" do
      activity = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "responses" => [
                %{
                  "id" => "response_1",
                  "rule" => "input like %{.*}",
                  "score" => 1,
                  "feedback" => %{
                    "id" => "feedback_1",
                    "content" => [
                      %{
                        "invalid_field" => "not allowed"
                      }
                    ]
                  }
                }
              ]
            }
          ]
        }
      }

      assert {:error, {"authoring.parts[0].responses[0].feedback.content[0]", _errors}} = 
        Validation.validate_activity(activity)
    end

    test "handles missing content gracefully" do
      activity = %{
        "stem" => %{},
        "choices" => [%{"id" => "choice_1"}],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "hints" => [%{"id" => "hint_1", "content" => []}],
              "responses" => [%{
                "id" => "response_1", 
                "rule" => "input like %{.*}", 
                "score" => 1,
                "feedback" => %{"id" => "feedback_1", "content" => []}
              }]
            }
          ]
        }
      }

      assert {:ok, %Oli.Activities.Model{}} = Validation.validate_activity(activity)
    end

    test "rejects when content is not a list" do
      activity = %{
        "stem" => %{
          "content" => "should be a list"
        }
      }

      assert {:error, {"stem.content", ["Content must be a list"]}} = 
        Validation.validate_activity(activity)
    end

    test "handles empty content lists" do
      activity = %{
        "stem" => %{
          "content" => []
        },
        "choices" => [
          %{
            "id" => "choice_1",
            "content" => []
          }
        ]
      }

      assert {:ok, %Oli.Activities.Model{}} = Validation.validate_activity(activity)
    end
  end

end