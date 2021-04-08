defmodule Oli.Content.Activity.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity

  import ExUnit.CaptureLog

  describe "html activity renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed activity properly", %{author: author} do
      activity_map = %{
        1 => %{
          id: 1,
          graded: false,
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "None",
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
               "<oli-multiple-choice-delivery class=\"activity-container\" graded=\"false\" state=\"{ \"active\": true }\" model=\"{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}\""
    end

    test "renders malformed activity gracefully", %{author: author} do
      activity_map = %{
        1 => %{
          id: 1,
          graded: false,
          slug: "test",
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "None",
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
                        "<div class=\"activity invalid alert alert-danger\">Activity is invalid"
             end) =~ "Activity is invalid"
    end

    test "handles missing activity from activity-map gracefully", %{author: author} do
      activity_map = %{
        5 => %{
          id: 5,
          graded: false,
          slug: "test",
          state: "{ \"active\": true }",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "activity_id" => 1,
        "children" => [],
        "id" => 4_097_071_352,
        "purpose" => "None",
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
                        "<div class=\"activity error alert alert-danger\">An error occurred and this activity could not be shown. Please contact support with issue"
             end) =~ "ActivitySummary with id 1 missing from activity_map"
    end
  end
end
