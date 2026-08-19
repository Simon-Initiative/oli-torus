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

    test "tags delivered alternative branches with their group id", %{author: author} do
      element = %{
        "type" => "alternatives",
        "id" => "preference-placement",
        "alternatives_id" => 23,
        "children" => [
          %{"type" => "alternative", "value" => "a", "children" => []},
          %{"type" => "alternative", "value" => "b", "children" => []}
        ]
      }

      rendered =
        Alternatives.render(
          %Context{
            user: author,
            activity_map: %{},
            alternatives_groups_fn: fn ->
              {:ok, [%{id: 23, strategy: "select_all", options: []}]}
            end,
            alternatives_selector_fn: &Oli.Resources.Alternatives.SelectAllStrategy.select/2,
            mode: :delivery
          },
          element,
          Alternatives.Html
        )
        |> Phoenix.HTML.raw()
        |> Phoenix.HTML.safe_to_string()

      assert rendered =~
               ~s|class="alternative alternative-a" data-alternatives-id="23"|

      assert rendered =~
               ~s|class="alternative alternative-b" data-alternatives-id="23"|
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

      assert rendered_html_string =~ ~s|phx-hook="PreviewAlternativesTabs"|
      assert rendered_html_string =~ ~s|role="tablist"|
      assert rendered_html_string =~ ~s|aria-label="Alternative content options"|
      assert rendered_html_string =~ ~s|role="tab"|
      assert rendered_html_string =~ ~s|aria-selected="true"|

      assert rendered_html_string =~
               ~s|class="btn btn-sm mr-2 whitespace-nowrap bg-primary text-white dark:bg-blue-600 dark:text-white"|

      assert rendered_html_string =~
               ~s|class="btn btn-sm mr-2 whitespace-nowrap hover:bg-gray-200 dark:text-gray-100 dark:hover:bg-gray-700"|

      assert rendered_html_string =~ ~s|role="tabpanel"|
      assert rendered_html_string =~ ~s| hidden>|

      # renders R alternative
      assert rendered_html_string =~
               ~s|<div class="content" ><p data-point-marker="19094070">R</p>|

      # renders activity embedded in R alternative
      assert rendered_html_string =~
               ~s|<oli-multiple-choice-delivery id="activity-1" phx-update="ignore" class="activity-container" state="{ "active": true }" model="{ "choices": [ "A", "B", "C", "D" ], "feedback": [ "A", "B", "C", "D" ], "stem": ""}" mode="author_preview"|

      # renders Excel alternative
      assert rendered_html_string =~
               ~s|<div class=\"content\" ><p data-point-marker="1742467879">Excel</p>\n</div>|

      # renders Python alternative
      assert rendered_html_string =~
               ~s|<div class=\"content\" ><p data-point-marker="378189886">Python</p>\n</div>|
    end

    test "treats legacy upgrade decision points as experiment-controlled in preview", %{
      author: author
    } do
      element = %{
        "type" => "alternatives",
        "id" => "legacy-placement",
        "alternatives_id" => 1,
        "strategy" => "user_section_preference",
        "children" => [
          %{"type" => "alternative", "value" => "a", "children" => []},
          %{"type" => "alternative", "value" => "b", "children" => []}
        ]
      }

      groups_fn = fn ->
        {:ok,
         [
           %{
             id: 1,
             revision_id: 1,
             title: "Legacy decision point",
             strategy: "upgrade_decision_point",
             options: [%{"id" => "a", "name" => "A"}, %{"id" => "b", "name" => "B"}]
           }
         ]}
      end

      rendered =
        Alternatives.render(
          %Context{
            user: author,
            activity_map: %{},
            alternatives_groups_fn: groups_fn,
            alternatives_selector_fn: &Oli.Resources.Alternatives.select/2,
            mode: :author_preview
          },
          element,
          Alternatives.Html
        )
        |> Phoenix.HTML.raw()
        |> Phoenix.HTML.safe_to_string()

      assert rendered =~ ~s|phx-hook="PreviewAlternativesTabs"|
      assert rendered =~ "Alternative 1"
      assert rendered =~ "Alternative 2"
      assert rendered =~ "Preview each alternative using the tabs below to switch between them"

      assert rendered =~
               "experiment policy assigns one alternative to each learner"

      assert rendered =~ "assignment stays with the learner for this intervention"
      refute rendered =~ "AlternativesPreferenceSelector"
      refute rendered =~ "alternatives-selector-1"
    end

    test "renders user preference alternatives with the dropdown instead of tabs in preview", %{
      author: author
    } do
      element = %{
        "type" => "alternatives",
        "id" => "preference-placement",
        "alternatives_id" => 1,
        "children" => [
          %{"type" => "alternative", "value" => "a", "children" => []},
          %{"type" => "alternative", "value" => "b", "children" => []}
        ]
      }

      groups_fn = fn ->
        {:ok,
         [
           %{
             id: 1,
             revision_id: 1,
             title: "Learner choice",
             strategy: "user_section_preference",
             options: [%{"id" => "a", "name" => "A"}, %{"id" => "b", "name" => "B"}]
           }
         ]}
      end

      rendered =
        Alternatives.render(
          %Context{
            user: author,
            activity_map: %{},
            alternatives_groups_fn: groups_fn,
            alternatives_selector_fn: &Oli.Resources.Alternatives.select/2,
            extrinsic_read_section_fn: fn _, _, _ -> {:ok, %{}} end,
            mode: :author_preview
          },
          element,
          Alternatives.Html
        )
        |> Phoenix.HTML.raw()
        |> Phoenix.HTML.safe_to_string()

      assert rendered =~ "AlternativesPreferenceSelector"
      assert rendered =~ "alternatives-selector-1"
      assert rendered =~ "Preview each alternative by selecting it from the list below"
      assert rendered =~ "stored as their preference for the section"
      refute rendered =~ ~s|phx-hook="PreviewAlternativesTabs"|
      refute rendered =~ ~s|role="tablist"|
    end
  end
end
