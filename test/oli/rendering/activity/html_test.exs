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
        "activity-1" => %{
          slug: "activity-1",
          model_json: "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "activitySlug" => "activity-1",
        "children" => [],
        "id" => 4097071352,
        "purpose" => "None",
        "type" => "activity-reference"
      }

      rendered_html = Activity.render(%Context{user: author, activity_map: activity_map}, element, Activity.Html)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

      assert rendered_html_string =~ "<oli-multiple-choice-delivery class=\"activity\" model=\"{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}\""
    end

    test "renders malformed activity gracefully", %{author: author} do
      activity_map = %{
        "activity-1" => %{
          slug: "activity-1",
          model_json: "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "children" => [],
        "id" => 4097071352,
        "purpose" => "None",
        "type" => "activity-reference"
      }

      assert capture_log(fn ->
        rendered_html = Activity.render(%Context{user: author, activity_map: activity_map}, element, Activity.Html)
        rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

        assert rendered_html_string =~ "<div class=\"activity invalid\">Activity is invalid</div>"
      end) =~ "Activity is invalid"
    end

    test "handles missing activity from activity-map gracefully", %{author: author} do
      activity_map = %{
        "activity-5" => %{
          slug: "activity-5",
          model_json: "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery"
        }
      }

      element = %{
        "activitySlug" => "activity-1",
        "children" => [],
        "id" => 4097071352,
        "purpose" => "None",
        "type" => "activity-reference"
      }

      assert capture_log(fn ->
        rendered_html = Activity.render(%Context{user: author, activity_map: activity_map}, element, Activity.Html)
        rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

        assert rendered_html_string =~ "<div class=\"activity error\">This activity could not be rendered"
      end) =~ "Activity summary with slug activity-1 missing from activity_map"
    end
  end
end
