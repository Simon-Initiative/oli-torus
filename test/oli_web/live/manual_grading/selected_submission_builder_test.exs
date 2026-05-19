defmodule OliWeb.ManualGrading.SelectedSubmissionBuilderTest do
  use ExUnit.Case, async: true

  alias OliWeb.ManualGrading.SelectedSubmissionBuilder

  test "builds a typed dropdown view for regular multi input parts" do
    attempt = %{
      activity_type_id: 10,
      revision: %{
        content: %{
          "stem" => %{
            "content" => [
              %{
                "type" => "p",
                "children" => [
                  %{"text" => "Element:"},
                  %{"type" => "input_ref", "id" => "input-1"},
                  %{"text" => ""}
                ]
              }
            ]
          },
          "inputs" => [
            %{
              "id" => "input-1",
              "partId" => "part-1",
              "inputType" => "dropdown",
              "choiceIds" => ["choice-a", "choice-b"]
            }
          ],
          "choices" => [
            %{"id" => "choice-a", "content" => [%{"text" => "Hydrogen"}]},
            %{"id" => "choice-b", "content" => [%{"text" => "Helium"}]}
          ],
          "authoring" => %{"parts" => [%{"id" => "part-1"}]}
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "part-1",
      response: %{"input" => "choice-b"},
      score: 1.0,
      out_of: 1.0
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{10 => %{slug: "oli_multi_input"}}
      )

    assert submission.title == "Question Response"
    assert submission.subtitle == "Dropdown • Part ID: part-1"
    assert submission.score == "1.0 / 1.0"
    assert submission.response_view.kind == :choice_list
    assert submission.response_view.prompt == "Element:"
    assert submission.response_view.selected_summary == "Helium"
    assert Enum.any?(submission.response_view.choices, &(&1.label == "Helium" and &1.selected))
  end

  test "builds a typed text view for regular multi input parts" do
    attempt = %{
      activity_type_id: 10,
      revision: %{
        content: %{
          "stem" => %{
            "content" => [
              %{
                "type" => "p",
                "children" => [
                  %{"text" => "Planet:"},
                  %{"type" => "input_ref", "id" => "input-1"},
                  %{"text" => ""}
                ]
              }
            ]
          },
          "inputs" => [
            %{
              "id" => "input-1",
              "partId" => "part-1",
              "inputType" => "text"
            }
          ],
          "authoring" => %{"parts" => [%{"id" => "part-1"}]}
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "part-1",
      response: %{"input" => "Mercury"},
      score: nil,
      out_of: 2.0
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{10 => %{slug: "oli_multi_input"}}
      )

    assert submission.subtitle == "Text • Part ID: part-1"
    assert submission.score == "Pending / 2.0"
    assert submission.response_view.kind == :value
    assert submission.response_view.prompt == "Planet:"
    assert submission.response_view.value == "Mercury"
  end

  test "builds a typed choice view for regular single part multiple choice activities" do
    attempt = %{
      activity_type_id: 11,
      revision: %{
        content: %{
          "stem" => %{"content" => [%{"type" => "p", "children" => [%{"text" => "Choose one"}]}]},
          "choices" => [
            %{"id" => "choice-a", "content" => [%{"text" => "Option A"}]},
            %{"id" => "choice-b", "content" => [%{"text" => "Option B"}]}
          ]
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "1",
      response: %{"input" => "choice-b"},
      score: 1.0,
      out_of: 1.0
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{11 => %{slug: "oli_multiple_choice"}}
      )

    assert submission.title == "Question Response"
    assert submission.subtitle == "Multiple Choice • Part ID: 1"
    assert submission.response_view.kind == :choice_list
    assert submission.response_view.prompt == "Choose one"
    assert submission.response_view.selected_summary == "Option B"
  end

  test "builds a prose view for regular single part short answer activities" do
    attempt = %{
      activity_type_id: 12,
      revision: %{
        content: %{
          "stem" => %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "Name the planet"}]}]
          }
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "1",
      response: %{"input" => "Mars"},
      score: nil,
      out_of: 1.0
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{12 => %{slug: "oli_short_answer"}}
      )

    assert submission.title == "Question Response"
    assert submission.subtitle == "Short Answer • Part ID: 1"
    assert submission.response_view.kind == :prose
    assert submission.response_view.prompt == "Name the planet"
    assert submission.response_view.value == "Mars"
  end

  test "builds an adaptive fill blanks view from stage response entries" do
    attempt = %{
      activity_type_id: 13,
      revision: %{
        content: %{
          "partsLayout" => [
            %{
              "id" => "janus_fill_blanks-1",
              "type" => "janus-fill-blanks",
              "custom" => %{
                "elements" => [
                  %{"key" => "blank1"},
                  %{"key" => "blank2"}
                ]
              }
            }
          ],
          "authoring" => %{
            "parts" => [
              %{"id" => "janus_fill_blanks-1", "type" => "janus-fill-blanks"}
            ]
          }
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "janus_fill_blanks-1",
      response: %{
        "blank1" => %{
          "path" => "screen|stage.janus_fill_blanks-1.Input 1.Value",
          "value" => "Mercury"
        },
        "blank2" => %{
          "path" => "screen|stage.janus_fill_blanks-1.Input 2.Value",
          "value" => "Venus"
        }
      },
      score: nil,
      out_of: nil
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{13 => %{slug: "oli_adaptive"}}
      )

    assert submission.subtitle == "Fill Blanks • Part ID: janus_fill_blanks-1"
    assert submission.response_view.kind == :fill_blanks

    assert submission.response_view.blanks == [
             %{label: "blank1", value: "Mercury", meta: nil},
             %{label: "blank2", value: "Venus", meta: nil}
           ]
  end

  test "builds an adaptive fill blanks view from plain input values" do
    attempt = %{
      activity_type_id: 13,
      revision: %{
        content: %{
          "partsLayout" => [
            %{
              "id" => "janus_fill_blanks-1",
              "type" => "janus-fill-blanks",
              "custom" => %{
                "elements" => [
                  %{"key" => "blank1"},
                  %{"key" => "blank2"}
                ]
              }
            }
          ],
          "authoring" => %{
            "parts" => [
              %{"id" => "janus_fill_blanks-1", "type" => "janus-fill-blanks"}
            ]
          }
        }
      }
    }

    part_attempt = %{
      attempt_guid: "attempt-1",
      part_id: "janus_fill_blanks-1",
      response: %{
        "input" => %{
          "blank1" => "Mercury",
          "blank2" => "Venus"
        }
      },
      score: nil,
      out_of: nil
    }

    submission =
      SelectedSubmissionBuilder.build(
        attempt,
        [part_attempt],
        "attempt-1",
        %{13 => %{slug: "oli_adaptive"}}
      )

    assert submission.response_view.kind == :fill_blanks

    assert submission.response_view.blanks == [
             %{label: "blank1", value: "Mercury", meta: nil},
             %{label: "blank2", value: "Venus", meta: nil}
           ]
  end
end
