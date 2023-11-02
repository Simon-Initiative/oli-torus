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
      id: part_id,
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
             |> ResponseLabel.build("oli_adaptive")

    assert %ResponseLabel{response: "unsupported", label: "unsupported"} =
             attempt_with_response("something")
             |> ResponseLabel.build("oli_embedded")

    assert %ResponseLabel{response: "unsupported", label: "unsupported"} =
             attempt_with_response("something")
             |> ResponseLabel.build("oli_image_coding")
  end
end
