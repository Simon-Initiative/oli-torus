defmodule Oli.Content.Activity.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Activity.ActivitySummary

  import ExUnit.CaptureLog

  describe "html activity renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed activity properly", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      rendered_html =
        Activity.render(
          %Context{user: author, activity_map: activity_map},
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<oli-multiple-choice-delivery id="activity-1" phx-update="ignore" class="activity-container" state="{ "active": true }" model="{ "choices": [ "A", "B", "C", "D" ], "feedback": [ "A", "B", "C", "D" ], "stem": ""}"|
    end

    test "renders malformed activity gracefully", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{user: author, activity_map: activity_map},
                   element,
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string =~
                        "<div class=\"alert alert-danger\">Activity render error"
             end) =~ "Activity render error"
    end

    test "handles missing activity from activity-map gracefully", %{author: author} do
      activity_map = %{
        5 => %ActivitySummary{
          id: 5,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "none",
        "type" => "activity-reference"
      }

      assert capture_log(fn ->
               rendered_html =
                 Activity.render(
                   %Context{user: author, activity_map: activity_map},
                   element,
                   Activity.Html
                 )

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string =~
                        "<div class=\"alert alert-danger\">ActivitySummary with id 1 missing from activity_map"
             end) =~ "ActivitySummary with id 1 missing from activity_map"
    end
  end
end
