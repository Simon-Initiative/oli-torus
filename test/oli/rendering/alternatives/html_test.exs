defmodule Oli.Rendering.Alternatives.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Alternatives
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
        "alternatives_id" => 1,
        "children" => [
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "text" => "R"
                      }
                    ],
                    "id" => "19094070",
                    "type" => "p"
                  }
                ],
                "id" => "2827117032",
                "type" => "content"
              },
              %{
                "activity_id" => 1,
                "children" => [],
                "id" => "1087498156",
                "type" => "activity-reference"
              }
            ],
            "id" => "2849392801",
            "type" => "alternative",
            "value" => "DhY8ERStw7vXActR5U5BqR"
          },
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "text" => "Excel"
                      }
                    ],
                    "id" => "1742467879",
                    "type" => "p"
                  }
                ],
                "id" => "1517350867",
                "type" => "content"
              }
            ],
            "id" => "3131295689",
            "type" => "alternative",
            "value" => "kQqFWsHyXeMenEDzT9rymP"
          },
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "text" => "Python"
                      }
                    ],
                    "id" => "378189886",
                    "type" => "p"
                  }
                ],
                "id" => "1145582186",
                "type" => "content"
              }
            ],
            "id" => "3536915303",
            "type" => "alternative",
            "value" => "bdaqYkKs8RFE4LWLmPCLnf"
          }
        ],
        "id" => "2606495871",
        "strategy" => "select_all",
        "type" => "alternatives"
      }

      mock_alternatives_groups_fn = fn ->
        {:ok,
         [
           %{
             id: 1,
             title: "Stats Package",
             strategy: "select_all",
             options: [
               %{
                 "id" => "bdaqYkKs8RFE4LWLmPCLnf",
                 "name" => "Python"
               },
               %{
                 "id" => "kQqFWsHyXeMenEDzT9rymP",
                 "name" => "Excel"
               },
               %{
                 "id" => "DhY8ERStw7vXActR5U5BqR",
                 "name" => "R"
               }
             ]
           }
         ]}
      end

      mock_alternatives_selector_fn = fn context, alternatives_element ->
        Oli.Resources.Alternatives.SelectAllStrategy.select(context, alternatives_element)
      end

      rendered_html =
        Alternatives.render(
          %Context{
            user: author,
            activity_map: activity_map,
            alternatives_groups_fn: mock_alternatives_groups_fn,
            alternatives_selector_fn: mock_alternatives_selector_fn,
            mode: :author_preview
          },
          element,
          Alternatives.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # renders R alternative
      assert rendered_html_string =~
               ~s|<div class="alternative alternative-DhY8ERStw7vXActR5U5BqR"><div class="content" ><p data-point-marker="19094070">R</p>|

      # renders activity embedded in R alternative
      assert rendered_html_string =~
               ~s|<oli-multiple-choice-delivery id="activity-1" phx-update="ignore" class="activity-container" state="{ "active": true }" model="{ "choices": [ "A", "B", "C", "D" ], "feedback": [ "A", "B", "C", "D" ], "stem": ""}" mode="author_preview"|

      # renders Excel alternative
      assert rendered_html_string =~
               ~s|<div class="alternative alternative-kQqFWsHyXeMenEDzT9rymP"><div class=\"content\" ><p data-point-marker="1742467879">Excel</p>\n</div>|

      # renders Python alternative
      assert rendered_html_string =~
               ~s|<div class="alternative alternative-bdaqYkKs8RFE4LWLmPCLnf"><div class=\"content\" ><p data-point-marker="378189886">Python</p>\n</div>|
    end
  end
end
