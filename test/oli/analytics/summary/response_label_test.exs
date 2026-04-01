defmodule Oli.Analytics.Summary.ResponseLabelTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.Summary.ResponseLabel

  @reusable_model %{
    "choices" => [
      %{"id" => "1", "content" => %{}},
      %{"id" => "2", "content" => %{}},
      %{"id" => "3", "content" => %{}},
      %{"id" => "4", "content" => %{}},
      %{"id" => "5", "content" => %{}},
      %{"id" => "6", "content" => %{}}
    ],
    "inputs" => [
      %{"id" => "1", "partId" => "part1", "inputType" => "text"},
      %{"id" => "2", "partId" => "part2", "inputType" => "numeric"},
      %{
        "id" => "3",
        "partId" => "part3",
        "inputType" => "dropdown",
        "choiceIds" => ["3", "4", "6"]
      }
    ],
    "authoring" => %{
      "parts" => [
        %{"id" => "part1", "content" => %{}},
        %{"id" => "part2", "content" => %{}},
        %{"id" => "part3", "content" => %{}}
      ]
    }
  }

  defp attempt_with_response(response, part_id \\ "part1") do
    %{
      part_id: part_id,
      activity_revision: %{
        content: @reusable_model,
        resource_id: 33
      },
      response: %{"input" => response}
    }
  end

  defp set_descending(part_attempt) do
    content = part_attempt.activity_revision.content |> Map.put("orderDescending", true)
    activity_revision = part_attempt.activity_revision |> Map.put(:content, content)
    Map.put(part_attempt, :activity_revision, activity_revision)
  end

  defp adaptive_attempt(part_id, type, response, custom \\ %{}) do
    %{
      part_id: part_id,
      activity_revision: %{
        content: %{
          "partsLayout" => [
            %{
              "id" => part_id,
              "type" => type,
              "custom" => custom
            }
          ]
        },
        resource_id: 44
      },
      response: response
    }
  end

  test "choice labelling" do
    assert %ResponseLabel{response: "2", label: "B"} =
             attempt_with_response("2")
             |> ResponseLabel.build("oli_multiple_choice")

    assert %ResponseLabel{response: "", label: "No answer"} =
             attempt_with_response(nil)
             |> ResponseLabel.build("oli_multiple_choice")

    assert %ResponseLabel{response: "2 4 6", label: "B, D, F"} =
             attempt_with_response("2 4 6")
             |> ResponseLabel.build("oli_check_all_that_apply")

    assert %ResponseLabel{response: "", label: "No answer"} =
             attempt_with_response(nil)
             |> ResponseLabel.build("oli_check_all_that_apply")

    assert %ResponseLabel{response: "1 2 3 4 5 6", label: "A, B, C, D, E, F"} =
             attempt_with_response("1 2 3 4 5 6")
             |> ResponseLabel.build("oli_ordering")

    assert %ResponseLabel{response: "", label: "No answer"} =
             attempt_with_response(nil)
             |> ResponseLabel.build("oli_ordering")

    assert %ResponseLabel{response: "3", label: "C"} =
             attempt_with_response("3")
             |> ResponseLabel.build("oli_image_hotspot")

    assert %ResponseLabel{response: "2", label: "2"} =
             attempt_with_response("2")
             |> ResponseLabel.build("oli_likert")

    assert %ResponseLabel{response: "2", label: "5"} =
             attempt_with_response("2")
             |> set_descending()
             |> ResponseLabel.build("oli_likert")

    assert %ResponseLabel{response: "", label: "No answer"} =
             attempt_with_response(nil)
             |> ResponseLabel.build("oli_likert")
  end

  test "text response labelling" do
    assert %ResponseLabel{response: "here is my answer", label: "here is my answer"} =
             attempt_with_response("here is my answer")
             |> ResponseLabel.build("oli_short_answer")

    assert %ResponseLabel{response: "", label: "No answer"} =
             attempt_with_response(nil)
             |> ResponseLabel.build("oli_short_answer")
  end

  test "multi input" do
    assert %ResponseLabel{response: "here is my answer", label: "here is my answer"} =
             attempt_with_response("here is my answer")
             |> ResponseLabel.build("oli_multi_input")

    assert %ResponseLabel{response: "25.4", label: "25.4"} =
             attempt_with_response("25.4", "part2")
             |> ResponseLabel.build("oli_multi_input")

    assert %ResponseLabel{response: "3", label: "A"} =
             attempt_with_response("3", "part3")
             |> ResponseLabel.build("oli_multi_input")
  end

  test "adaptive responses" do
    mcq_response = %{
      "selectedChoice" => %{
        "path" => "screen|stage.janus_mcq-1.selectedChoice",
        "value" => 2
      },
      "selectedChoiceText" => %{
        "path" => "screen|stage.janus_mcq-1.selectedChoiceText",
        "value" => "Option 2"
      },
      "selectedChoices" => %{
        "path" => "screen|stage.janus_mcq-1.selectedChoices",
        "value" => [2]
      },
      "selectedChoicesText" => %{
        "path" => "screen|stage.janus_mcq-1.selectedChoicesText",
        "value" => ["Option 2"]
      }
    }

    assert %ResponseLabel{response: "2", label: "Option 2"} =
             adaptive_attempt(
               "janus_mcq-1",
               "janus-mcq",
               mcq_response,
               %{
                 "mcqItems" => [
                   %{"nodes" => [%{"text" => "Option 1"}]},
                   %{"nodes" => [%{"text" => "Option 2"}]}
                 ]
               }
             )
             |> ResponseLabel.build("oli_adaptive")

    dropdown_response = %{
      "selectedIndex" => %{
        "path" => "screen|stage.janus_dropdown-1.selectedIndex",
        "value" => 2
      },
      "selectedItem" => %{
        "path" => "screen|stage.janus_dropdown-1.selectedItem",
        "value" => "Option 2"
      }
    }

    assert %ResponseLabel{response: "2", label: "Option 2"} =
             adaptive_attempt(
               "janus_dropdown-1",
               "janus-dropdown",
               dropdown_response,
               %{"optionLabels" => ["Option 1", "Option 2"]}
             )
             |> ResponseLabel.build("oli_adaptive")

    assert %ResponseLabel{response: "typed answer", label: "typed answer"} =
             adaptive_attempt(
               "janus_input_text-1",
               "janus-input-text",
               %{
                 "value" => %{
                   "path" => "screen|stage.janus_input_text-1.value",
                   "value" => "typed answer"
                 }
               }
             )
             |> ResponseLabel.build("oli_adaptive")

    fill_blanks_response = %{
      "blank1" => %{
        "path" => "screen|stage.janus_fill_blanks-1.Input 1.Value",
        "value" => "Mercury"
      },
      "blank2" => %{
        "path" => "screen|stage.janus_fill_blanks-1.Input 2.Value",
        "value" => "Venus"
      }
    }

    assert %ResponseLabel{
             response: "Mercury | Venus",
             label: "blank1: Mercury; blank2: Venus"
           } =
             adaptive_attempt(
               "janus_fill_blanks-1",
               "janus-fill-blanks",
               fill_blanks_response,
               %{
                 "elements" => [
                   %{"key" => "blank1"},
                   %{"key" => "blank2"}
                 ]
               }
             )
             |> ResponseLabel.build("oli_adaptive")

    partial_fill_blanks_response = %{
      "blank1" => %{
        "path" => "screen|stage.janus_fill_blanks-1.Input 1.Value",
        "value" => "Mercury"
      }
    }

    assert %ResponseLabel{
             response: "Mercury | [blank]",
             label: "Blank 1: Mercury; Blank 2: No response"
           } =
             adaptive_attempt(
               "janus_fill_blanks-1",
               "janus-fill-blanks",
               partial_fill_blanks_response,
               %{
                 "elements" => [
                   %{},
                   %{}
                 ]
               }
             )
             |> ResponseLabel.build("oli_adaptive")
  end

  test "custom dnd" do
    assert %ResponseLabel{response: "part1", label: "A"} =
             attempt_with_response("part1")
             |> ResponseLabel.build("oli_custom_dnd")
  end

  test "unsupported" do
    assert %ResponseLabel{response: "unsupported", label: "unsupported"} =
             attempt_with_response("something")
             |> ResponseLabel.build("oli_file_upload")

    assert %ResponseLabel{response: "unsupported", label: "unsupported"} =
             attempt_with_response("something")
             |> ResponseLabel.build("oli_embedded")

    assert %ResponseLabel{response: "unsupported", label: "unsupported"} =
             attempt_with_response("something")
             |> ResponseLabel.build("oli_image_coding")
  end
end
