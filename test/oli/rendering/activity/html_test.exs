defmodule Oli.Content.Activity.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Delivery.Attempts.Core.ResourceAttempt

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

    test "includes pageState from extrinsic_state when present", %{author: author} do
      # Create extrinsic state
      extrinsic_state = %{
        "app.explorations.bpr" => "test-value",
        "session.currentQuestionScore" => 5
      }

      resource_attempt = %ResourceAttempt{
        attempt_guid: "test-guid-123",
        state: %{}
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: true,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "purpose" => "none"
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            activity_map: activity_map,
            resource_attempt: resource_attempt,
            extrinsic_state: extrinsic_state,
            mode: :review
          },
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # Verify that the pageState contains the extrinsic state
      assert rendered_html_string =~ "app.explorations.bpr"
      assert rendered_html_string =~ "test-value"
      assert rendered_html_string =~ "session.currentQuestionScore"
    end

    test "uses empty map for pageState when extrinsic_state is nil", %{author: author} do
      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: true,
          state: "{ \"active\": true }",
          model: "{ \"stem\": \"test\" }",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "activity-guid-456",
          lifecycle_state: :active
        }
      }

      element = %{
        "activity_id" => 1,
        "purpose" => "none"
      }

      rendered_html =
        Activity.render(
          %Context{
            user: author,
            activity_map: activity_map,
            resource_attempt: nil,
            extrinsic_state: nil,
            mode: :review
          },
          element,
          Activity.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # Should render successfully without errors
      assert rendered_html_string =~ "oli-multiple-choice-delivery"
      # The pageState should be present but empty (encoded as {})
      assert rendered_html_string =~ ~r/context=".*pageState.*"/
    end
  end
end
