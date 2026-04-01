defmodule OliWeb.Delivery.ActivityHelpersTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.User
  alias OliWeb.Delivery.ActivityHelpers

  describe "stage_performance_details/3 for check-all-that-apply" do
    test "marks only non-negated choices as correct and aggregates counts per choice" do
      cata_id = 1

      model = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_1",
              "responses" => [
                %{
                  "rule" => "(!(input like {choice_a})) && (input like {choice_b})",
                  "score" => 1
                }
              ]
            }
          ]
        },
        "choices" => [
          %{"id" => "choice_a"},
          %{"id" => "choice_b"},
          %{"id" => "choice_c"}
        ]
      }

      activities = [
        %{
          resource_id: 10,
          revision: %{activity_type_id: cata_id, content: model},
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{activity_id: 10, response: "choice_a choice_b", count: 2},
        %{activity_id: 10, response: "choice_b", count: 1},
        %{activity_id: 10, response: "choice_c", count: 3},
        %{activity_id: 11, response: "choice_a", count: 5}
      ]

      [%{student_responses: %{"part_1" => responses}}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{cata_id => %{title: "Check All That Apply"}},
          response_summaries
        )

      assert [
               %{
                 "label" => "A.",
                 "count" => 2,
                 "correct" => false,
                 "part_id" => "part_1"
               },
               %{
                 "label" => "B.",
                 "count" => 3,
                 "correct" => true,
                 "part_id" => "part_1"
               },
               %{
                 "label" => "C.",
                 "count" => 3,
                 "correct" => false,
                 "part_id" => "part_1"
               }
             ] = responses
    end
  end

  describe "stage_performance_details/3 for multiple choice" do
    test "adds counts and correct choice metadata" do
      mc_id = 2

      model = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "part_mc",
              "responses" => [
                %{"rule" => "(input like {correct})", "score" => 1},
                %{"rule" => "(input like {wrong})", "score" => 0}
              ]
            }
          ]
        },
        "choices" => [
          %{"id" => "correct"},
          %{"id" => "wrong"}
        ]
      }

      activities = [
        %{
          resource_id: 20,
          revision: %{activity_type_id: mc_id, content: model},
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{activity_id: 20, response: "correct", count: 4},
        %{activity_id: 20, response: "wrong", count: 1},
        %{activity_id: 21, response: "correct", count: 99}
      ]

      [%{student_responses: %{"part_mc" => responses}}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{mc_id => %{title: "Multiple Choice"}},
          response_summaries
        )

      assert [
               %{
                 "label" => "A.",
                 "count" => 4,
                 "correct" => true,
                 "part_id" => "part_mc"
               },
               %{
                 "label" => "B.",
                 "count" => 1,
                 "correct" => false,
                 "part_id" => "part_mc"
               }
             ] = responses
    end
  end

  describe "stage_performance_details/3 for adaptive screens" do
    test "adds per-input response summaries for adaptive parts" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 50,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_text",
                  "type" => "janus-fill-blanks",
                  "custom" => %{"title" => "Blank 1"}
                },
                %{"id" => "part_dropdown", "type" => "janus-dropdown"}
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_text",
              num_first_attempts_correct: 3,
              num_first_attempts: 5,
              num_correct: 4,
              num_attempts: 5
            },
            %{
              part_id: "part_dropdown",
              num_first_attempts_correct: 1,
              num_first_attempts: 4,
              num_correct: 2,
              num_attempts: 4
            }
          ],
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{
          activity_id: 50,
          part_id: "part_text",
          count: 3,
          users: [%User{id: 1, given_name: "Ann", family_name: "Smith"}]
        },
        %{
          activity_id: 50,
          part_id: "part_text",
          count: 2,
          users: [%User{id: 2, given_name: "Bob", family_name: "Jones"}]
        },
        %{
          activity_id: 50,
          part_id: "part_dropdown",
          count: 4,
          users: [%User{id: 1, given_name: "Ann", family_name: "Smith"}]
        },
        %{activity_id: 51, part_id: "ignored", count: 99, users: []}
      ]

      [%{adaptive_input_summaries: summaries}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          response_summaries
        )

      assert [
               %{
                 part_id: "part_text",
                 label: "Blank 1",
                 component_type: "Fill Blanks",
                 response_count: 5,
                 student_count: 2,
                 attempt_count: 5,
                 first_attempt_pct: 0.6,
                 all_attempt_pct: 0.8,
                 order: 1
               },
               %{
                 part_id: "part_dropdown",
                 label: "Input 2",
                 component_type: "Dropdown",
                 response_count: 4,
                 student_count: 1,
                 attempt_count: 4,
                 first_attempt_pct: 0.25,
                 all_attempt_pct: 0.5,
                 order: 2
               }
             ] = summaries
    end
  end

  describe "stage_performance_details/3 for single response" do
    test "adds responses with user names" do
      sr_id = 3

      activities = [
        %{
          resource_id: 30,
          revision: %{activity_type_id: sr_id, content: %{}},
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{
          activity_id: 30,
          response: "First answer",
          users: [%User{given_name: "Ann", family_name: "Smith"}]
        },
        %{
          activity_id: 30,
          response: "Second answer",
          users: [%User{name: "Bob"}]
        },
        %{activity_id: 31, response: "Ignored", users: []}
      ]

      [%{revision: %{content: %{"responses" => responses}}}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{sr_id => %{title: "Single Response"}},
          response_summaries
        )

      assert [
               %{text: "First answer", users: ["Smith, Ann"]},
               %{text: "Second answer", users: ["Bob"]}
             ] = responses
    end
  end

  describe "stage_performance_details/3 for multi input" do
    test "adds freeform responses and dropdown frequencies" do
      mi_id = 4

      activities = [
        %{
          resource_id: 40,
          revision: %{
            activity_type_id: mi_id,
            content: %{
              "inputs" => [
                %{"inputType" => "text", "partId" => "text_part"},
                %{"inputType" => "dropdown", "partId" => "drop_part", "choiceIds" => ["1", "2"]}
              ],
              "choices" => [
                %{"id" => "1"},
                %{"id" => "2"}
              ],
              "authoring" => %{}
            }
          },
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{
          activity_id: 40,
          response: "Hello world",
          users: [%User{given_name: "Casey", family_name: "Lee"}],
          part_id: "text_part"
        },
        %{activity_id: 40, response: "1", count: 2, users: [], part_id: "drop_part"},
        %{activity_id: 40, response: "", count: 1, users: [], part_id: "drop_part"}
      ]

      [%{revision: %{content: content}}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{mi_id => %{title: "Multi Input"}},
          response_summaries
        )

      responses = content["authoring"]["responses"] |> Enum.sort_by(& &1.text)

      assert [
               %{text: "", users: [], type: "dropdown", part_id: "drop_part"},
               %{text: "1", users: [], type: "dropdown", part_id: "drop_part"},
               %{text: "Hello world", users: ["Lee, Casey"], type: "text", part_id: "text_part"}
             ] = responses

      assert [
               %{"frequency" => 1, "content" => [%{"children" => [%{"text" => _}]} | _]},
               %{"id" => "1", "frequency" => 2},
               %{"id" => "2", "frequency" => 0}
             ] = content["choices"]

      dropdown = content["inputs"] |> Enum.find(&(&1["inputType"] == "dropdown"))
      assert ["1", "2", "0"] = dropdown["choiceIds"]
    end
  end

  describe "stage_performance_details/3 for likert" do
    test "builds datasets with medians and values" do
      likert_id = 5

      activities = [
        %{
          resource_id: 50,
          revision: %{
            activity_type_id: likert_id,
            title: "Satisfaction Survey",
            content: %{
              "items" => [
                %{"id" => "q1", "content" => [%{"children" => [%{"text" => "Question 1"}]}]},
                %{"id" => "q2", "content" => [%{"children" => [%{"text" => "Question 2"}]}]}
              ],
              "choices" => [
                %{"id" => "c1", "content" => [%{"children" => [%{"text" => "No"}]}]},
                %{"id" => "c2", "content" => [%{"children" => [%{"text" => "Yes"}]}]}
              ]
            }
          },
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{activity_id: 50, response: "c1", part_id: "q1", count: 1},
        %{activity_id: 50, response: "c2", part_id: "q2", count: 2}
      ]

      [%{datasets: %{medians: medians, values: values}}] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{likert_id => %{title: "Likert"}},
          response_summaries
        )

      assert [%{question: "Question 1", median: 1.0}, %{question: "Question 2", median: 2.0}] =
               Enum.sort_by(medians, & &1.question)

      assert [
               %{choice: "No", question: "Question 1", out_of: 1, value: 1},
               %{choice: "Yes", question: "Question 2", out_of: 2, value: 2},
               %{choice: "Yes", question: "Question 2", out_of: 2, value: 2}
             ] = Enum.sort_by(values, &{&1.question, &1.choice})
    end
  end

  describe "stage_performance_details/3 fallback" do
    test "returns activity untouched for unknown types" do
      activities = [
        %{resource_id: 60, revision: %{activity_type_id: 999}, transformed_model: nil}
      ]

      assert ^activities =
               ActivityHelpers.stage_performance_details(activities, %{}, [
                 %{activity_id: 60, response: "whatever", count: 1}
               ])
    end
  end
end
