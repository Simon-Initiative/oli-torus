defmodule Oli.Content.Survey.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Survey
  alias Oli.Rendering.Activity.ActivitySummary

  describe "html activity renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed survey properly", %{author: author} do
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
        "children" => [
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "text" => "Please complete the following survey:"
                  }
                ],
                "id" => "3166489545",
                "type" => "p"
              }
            ],
            "id" => "2831392656",
            "type" => "content"
          },
          %{
            "activity_id" => 1,
            "children" => [],
            "id" => "1087498156",
            "type" => "activity-reference"
          }
        ],
        "id" => "1855946510",
        "type" => "survey"
      }

      rendered_html =
        Survey.render(
          %Context{user: author, activity_map: activity_map},
          element,
          Survey.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<div id="1855946510" class="survey"><div class="survey-label">Survey</div><div class="survey-content">|

      assert rendered_html_string =~
               ~s|<p data-point-marker=\"3166489545\">Please complete the following survey:</p>\n</div><oli-multiple-choice-delivery id="activity-1" phx-update="ignore" class="activity-container" state="{ "active": true }" model="{ "choices": [ "A", "B", "C", "D" ], "feedback": [ "A", "B", "C", "D" ], "stem": ""}" mode="delivery"|

      assert rendered_html_string =~
               ~s|</oli-multiple-choice-delivery>|

      assert rendered_html_string =~
               ~s|<div data-react-class="Components.SurveyControls" data-react-props="{&quot;id&quot;:&quot;1855946510&quot;,&quot;isSubmitted&quot;:null}"></div>|
    end
  end
end
