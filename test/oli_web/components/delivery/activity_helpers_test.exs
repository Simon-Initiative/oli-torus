defmodule OliWeb.Delivery.ActivityHelpersTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Delivery.ActivityHelpers
  import Phoenix.LiveViewTest

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
    test "adds typed aggregate summaries for adaptive parts" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 50,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_mcq",
                  "type" => "janus-mcq",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "MCQ 1",
                    "correctAnswer" => [false, true, false],
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]},
                      %{"nodes" => [%{"text" => "Option 3"}]}
                    ]
                  }
                },
                %{
                  "id" => "part_text",
                  "type" => "janus-input-text",
                  "gradingApproach" => "manual",
                  "custom" => %{"title" => "Short Text"}
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_mcq",
              num_first_attempts_correct: 3,
              num_first_attempts: 5,
              num_correct: 4,
              num_attempts: 5
            },
            %{
              part_id: "part_text",
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
          part_id: "part_mcq",
          response: "1",
          count: 1,
          users: [%User{id: 1, given_name: "Ann", family_name: "Smith"}]
        },
        %{
          activity_id: 50,
          part_id: "part_mcq",
          response: "2",
          count: 3,
          users: [%User{id: 2, given_name: "Bob", family_name: "Jones"}]
        },
        %{
          activity_id: 50,
          part_id: "part_mcq",
          response: "3",
          count: 1,
          users: [%User{id: 3, given_name: "Cory", family_name: "Lee"}]
        },
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
        %{activity_id: 51, part_id: "ignored", count: 99, users: []}
      ]

      [
        %{
          adaptive_input_summaries: summaries,
          first_attempt_pct: first_attempt_pct,
          all_attempt_pct: all_attempt_pct
        }
      ] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          response_summaries
        )

      assert first_attempt_pct == 0.6
      assert all_attempt_pct == 0.6

      assert [
               %{
                 part_id: "part_mcq",
                 label: "MCQ 1",
                 component_type: "Mcq",
                 grading_mode: :automatic,
                 grading_mode_label: "Automatically Graded",
                 prompt: "MCQ 1",
                 response_count: 5,
                 submitted_response_count: 5,
                 student_count: 3,
                 attempt_count: 5,
                 first_attempt_pct: 0.6,
                 all_attempt_pct: 0.6,
                 grading_pending: false,
                 grading_pending_message: nil,
                 outcome_buckets: [
                   %{
                     label: "Correct on first try",
                     count: 3,
                     ratio: 0.6,
                     fill_class: "bg-emerald-500 dark:bg-emerald-400"
                   },
                   %{
                     label: "Correct after retry",
                     count: 0,
                     ratio: +0.0,
                     fill_class: "bg-violet-500 dark:bg-violet-400"
                   },
                   %{
                     label: "Still incorrect / incomplete",
                     count: 2,
                     ratio: 0.4,
                     fill_class: "bg-amber-500 dark:bg-amber-400"
                   }
                 ],
                 visualization: %{
                   kind: :choice_distribution,
                   prompt: "MCQ 1",
                   description: "Selected choice distribution",
                   summary: "Each bar shows how many learners selected that option.",
                   denominator_count: 5,
                   denominator_label: "responses",
                   choices: [
                     %{label: "Option 1", count: 1, ratio: 0.2, correct: false},
                     %{label: "Option 2", count: 3, ratio: 0.6, correct: true},
                     %{label: "Option 3", count: 1, ratio: 0.2, correct: false}
                   ]
                 },
                 order: 1
               },
               %{
                 part_id: "part_text",
                 label: "Short Text",
                 component_type: "Input Text",
                 grading_mode: :manual,
                 grading_mode_label: "Instructor Manual Grading",
                 prompt: "Short Text",
                 response_count: 0,
                 submitted_response_count: 5,
                 student_count: 0,
                 attempt_count: 0,
                 first_attempt_pct: 0,
                 all_attempt_pct: 0,
                 outcome_buckets: [],
                 grading_pending: true,
                 grading_pending_message:
                   "No grading has been recorded for this manually graded input yet. Metrics will appear after instructor grading is saved.",
                 visualization: %{
                   kind: :response_patterns,
                   prompt: "Short Text",
                   description: "Most common submitted text responses",
                   summary:
                     "Each bar shows how often learners submitted the same text response for this input.",
                   denominator_count: 0,
                   entries: []
                 },
                 order: 2
               }
             ] = summaries
    end

    test "builds response-pattern visualizations for adaptive text-style inputs" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 64,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_formula",
                  "type" => "janus-formula",
                  "gradingApproach" => "automatic",
                  "custom" => %{"title" => "Formula Input"}
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [
            %{activity_id: 64, part_id: "part_formula", response: "x+1", count: 3, users: []},
            %{activity_id: 64, part_id: "part_formula", response: "x+2", count: 1, users: []}
          ]
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert %{
               visualization: %{
                 kind: :response_patterns,
                 description: "Most common submitted formulas",
                 denominator_count: 4,
                 entries: [
                   %{label: "x+1", count: 3, ratio: 0.75},
                   %{label: "x+2", count: 1, ratio: 0.25}
                 ]
               }
             } = summary
    end

    test "builds numeric distribution visualizations for adaptive numeric inputs" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 65,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_number",
                  "type" => "janus-input-number",
                  "gradingApproach" => "automatic",
                  "custom" => %{"title" => "Number Input"}
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [
            %{activity_id: 65, part_id: "part_number", response: "3", count: 1, users: []},
            %{activity_id: 65, part_id: "part_number", response: "1", count: 2, users: []},
            %{activity_id: 65, part_id: "part_number", response: "2", count: 1, users: []}
          ]
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert %{
               visualization: %{
                 kind: :numeric_distribution,
                 description: "Ordered numeric response distribution",
                 denominator_count: 4,
                 entries: [
                   %{label: "1", count: 2, ratio: 0.5},
                   %{label: "2", count: 1, ratio: 0.25},
                   %{label: "3", count: 1, ratio: 0.25}
                 ],
                 stats: [
                   %{label: "Minimum", value: "1"},
                   %{label: "Average", value: "1.75"},
                   %{label: "Maximum", value: "3"}
                 ]
               }
             } = summary
    end

    test "uses authored text criteria to determine correctness for automatic adaptive text inputs" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 66,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_text",
                  "type" => "janus-input-text",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "Text Input",
                    "correctAnswer" => %{
                      "mustContain" => "planet",
                      "mustNotContain" => "star",
                      "minimumLength" => 6
                    }
                  }
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_text",
              num_first_attempts_correct: 0,
              num_first_attempts: 3,
              num_correct: 0,
              num_attempts: 3
            }
          ],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [
            %{activity_id: 66, part_id: "part_text", response: "planet", count: 2, users: []},
            %{
              activity_id: 66,
              part_id: "part_text",
              response: "small star",
              count: 1,
              users: []
            }
          ]
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert summary.first_attempt_pct == 0
      assert summary.all_attempt_pct == 2 / 3

      assert [
               %{label: "Correct on first try", count: 0, ratio: first_try_ratio},
               %{label: "Correct after retry", count: 2, ratio: retry_ratio},
               %{label: "Still incorrect / incomplete", count: 1, ratio: incorrect_ratio}
             ] =
               Enum.map(summary.outcome_buckets, fn bucket ->
                 %{label: bucket.label, count: bucket.count, ratio: bucket.ratio}
               end)

      assert_in_delta first_try_ratio, 0.0, 1.0e-6
      assert_in_delta retry_ratio, 2 / 3, 1.0e-6
      assert_in_delta incorrect_ratio, 1 / 3, 1.0e-6
    end

    test "uses authored numeric criteria to determine correctness for automatic adaptive numeric inputs" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 67,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_number",
                  "type" => "janus-input-number",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "Number Input",
                    "answer" => %{
                      "range" => true,
                      "correctMin" => 10,
                      "correctMax" => 20
                    }
                  }
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_number",
              num_first_attempts_correct: 1,
              num_first_attempts: 4,
              num_correct: 1,
              num_attempts: 4
            }
          ],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [
            %{activity_id: 67, part_id: "part_number", response: "12", count: 2, users: []},
            %{activity_id: 67, part_id: "part_number", response: "25", count: 1, users: []},
            %{activity_id: 67, part_id: "part_number", response: "9", count: 1, users: []}
          ]
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert summary.first_attempt_pct == 0.25
      assert summary.all_attempt_pct == 0.5

      assert [
               %{label: "Correct on first try", count: 1, ratio: first_try_ratio},
               %{label: "Correct after retry", count: 1, ratio: retry_ratio},
               %{label: "Still incorrect / incomplete", count: 2, ratio: incorrect_ratio}
             ] =
               Enum.map(summary.outcome_buckets, fn bucket ->
                 %{label: bucket.label, count: bucket.count, ratio: bucket.ratio}
               end)

      assert_in_delta first_try_ratio, 0.25, 1.0e-6
      assert_in_delta retry_ratio, 0.25, 1.0e-6
      assert_in_delta incorrect_ratio, 0.5, 1.0e-6
    end

    test "uses minimum length criteria for automatic adaptive multiline text inputs" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 68,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_multiline",
                  "type" => "janus-multi-line-text",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "Written Response",
                    "minimumLength" => 10
                  }
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_multiline",
              num_first_attempts_correct: 0,
              num_first_attempts: 3,
              num_correct: 0,
              num_attempts: 3
            }
          ],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [
            %{
              activity_id: 68,
              part_id: "part_multiline",
              response: "long enough answer",
              count: 2,
              users: []
            },
            %{activity_id: 68, part_id: "part_multiline", response: "short", count: 1, users: []}
          ]
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert summary.first_attempt_pct == 0
      assert summary.all_attempt_pct == 2 / 3
    end

    test "uses graded-only analytics for manual adaptive parts when grading has been recorded" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 52,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_text",
                  "type" => "janus-input-text",
                  "gradingApproach" => "manual",
                  "custom" => %{"title" => "Short Text"}
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [],
          %{
            {52, "part_text"} => %{
              responses: [
                %{
                  activity_id: 52,
                  part_id: "part_text",
                  response: "typed answer",
                  count: 2,
                  users: []
                }
              ],
              student_ids: MapSet.new([1, 2]),
              first_attempt_student_ids: MapSet.new([1]),
              attempt_count: 2,
              correct_count: 1,
              first_attempt_count: 2,
              first_attempt_correct_count: 1
            }
          }
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert %{
               response_count: 2,
               student_count: 2,
               attempt_count: 2,
               coverage_response_label: "First Input Responses",
               coverage_response_count: 2,
               coverage_student_label: "Uniques Students",
               coverage_student_count: 1,
               coverage_attempt_label: "First Input Attempts",
               coverage_attempt_count: 2,
               first_attempt_pct: 0.5,
               all_attempt_pct: 0.5,
               grading_pending: false,
               outcome_buckets: [
                 %{label: "Correct on first try", count: 1, ratio: 0.5},
                 %{label: "Correct after retry", count: 0, ratio: +0.0},
                 %{label: "Still incorrect / incomplete", count: 1, ratio: 0.5}
               ]
             } = summary
    end

    test "derives manual choice correctness from graded scores and marks partial choices distinctly" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 60,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_mcq",
                  "type" => "janus-mcq",
                  "gradingApproach" => "manual",
                  "custom" => %{
                    "title" => "Manual MCQ",
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]},
                      %{"nodes" => [%{"text" => "Option 3"}]}
                    ]
                  }
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [choice1, choice2, choice3] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [],
          %{
            {60, "part_mcq"} => %{
              responses: [
                %{
                  activity_id: 60,
                  part_id: "part_mcq",
                  response: "1",
                  count: 1,
                  correct_count: 1,
                  incorrect_count: 0,
                  partial_count: 0,
                  users: []
                },
                %{
                  activity_id: 60,
                  part_id: "part_mcq",
                  response: "2",
                  count: 1,
                  correct_count: 0,
                  incorrect_count: 1,
                  partial_count: 0,
                  users: []
                },
                %{
                  activity_id: 60,
                  part_id: "part_mcq",
                  response: "3",
                  count: 1,
                  correct_count: 0,
                  incorrect_count: 0,
                  partial_count: 1,
                  users: []
                }
              ],
              student_ids: MapSet.new([1, 2, 3]),
              first_attempt_student_ids: MapSet.new([1, 2, 3]),
              attempt_count: 3,
              correct_count: 1,
              first_attempt_count: 3,
              first_attempt_correct_count: 1
            }
          }
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)
        |> hd()
        |> Map.fetch!(:visualization)
        |> Map.fetch!(:choices)

      assert choice1.native_correct == false
      assert choice2.native_correct == false
      assert choice3.native_correct == false
      assert choice1.correctness == true
      assert choice2.correctness == false
      assert choice3.correctness == :partial
    end

    test "treats automatic choice inputs without authored correctness as correct by default" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 61,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_dropdown",
                  "type" => "janus-dropdown",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "Auto Dropdown",
                    "optionLabels" => ["Option 1", "Option 2"]
                  }
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_dropdown",
              num_first_attempts_correct: 0,
              num_first_attempts: 2,
              num_correct: 0,
              num_attempts: 2
            }
          ],
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{activity_id: 61, part_id: "part_dropdown", response: "1", count: 1, users: []},
        %{activity_id: 61, part_id: "part_dropdown", response: "2", count: 1, users: []}
      ]

      input_summary =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          response_summaries
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)
        |> hd()

      assert input_summary.first_attempt_pct == 1.0
      assert input_summary.all_attempt_pct == 1.0
      refute Map.get(input_summary.visualization, :native_key_note)
      assert Enum.all?(input_summary.visualization.choices, &(&1.correctness == true))
    end

    test "uses actual adaptive choice responses when correctness summary contradicts them" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 51,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "part_mcq",
                  "type" => "janus-mcq",
                  "gradingApproach" => "automatic",
                  "custom" => %{
                    "title" => "MCQ 1",
                    "correctAnswer" => [false, true, false],
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]},
                      %{"nodes" => [%{"text" => "Option 3"}]}
                    ]
                  }
                }
              ]
            }
          },
          resource_summaries: [
            %{
              part_id: "part_mcq",
              num_first_attempts_correct: 2,
              num_first_attempts: 2,
              num_correct: 2,
              num_attempts: 2
            }
          ],
          transformed_model: nil
        }
      ]

      response_summaries = [
        %{
          activity_id: 51,
          part_id: "part_mcq",
          response: "1",
          count: 2,
          users: [%User{id: 1, given_name: "Ann", family_name: "Smith"}]
        }
      ]

      [
        %{
          adaptive_input_summaries: [summary],
          first_attempt_pct: first_attempt_pct,
          all_attempt_pct: all_attempt_pct
        }
      ] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          response_summaries
        )

      assert first_attempt_pct == 0
      assert all_attempt_pct == 0

      assert summary.first_attempt_pct == 0
      assert summary.all_attempt_pct == 0

      assert [
               %{label: "Correct on first try", count: 0, ratio: +0.0},
               %{label: "Correct after retry", count: 0, ratio: +0.0},
               %{label: "Still incorrect / incomplete", count: 2, ratio: 1.0}
             ] =
               Enum.map(summary.outcome_buckets, fn bucket ->
                 %{label: bucket.label, count: bucket.count, ratio: bucket.ratio}
               end)
    end

    test "uses authoring.parts grading approach when partsLayout omits it" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 62,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "authoring" => %{
                "parts" => [
                  %{
                    "id" => "part_mcq",
                    "type" => "janus-mcq",
                    "gradingApproach" => "manual",
                    "outOf" => 1
                  }
                ]
              },
              "partsLayout" => [
                %{
                  "id" => "part_mcq",
                  "type" => "janus-mcq",
                  "custom" => %{
                    "title" => "MCQ from layout",
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]}
                    ]
                  }
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [summary] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [],
          %{
            {62, "part_mcq"} => %{
              responses: [
                %{
                  activity_id: 62,
                  part_id: "part_mcq",
                  response: "1",
                  count: 1,
                  correct_count: 1,
                  incorrect_count: 0,
                  partial_count: 0,
                  users: []
                }
              ],
              student_ids: MapSet.new([1]),
              first_attempt_student_ids: MapSet.new([1]),
              attempt_count: 1,
              correct_count: 1,
              first_attempt_count: 1,
              first_attempt_correct_count: 1
            }
          }
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)

      assert summary.grading_mode == :manual
      assert summary.grading_mode_label == "Instructor Manual Grading"
    end

    test "keeps native answer key separate from manual outcome when both exist" do
      adaptive_id = 99

      activities = [
        %{
          resource_id: 63,
          revision: %{
            activity_type_id: adaptive_id,
            content: %{
              "authoring" => %{
                "parts" => [
                  %{
                    "id" => "part_mcq",
                    "type" => "janus-mcq",
                    "gradingApproach" => "manual"
                  }
                ]
              },
              "partsLayout" => [
                %{
                  "id" => "part_mcq",
                  "type" => "janus-mcq",
                  "custom" => %{
                    "title" => "Native and Manual",
                    "correctAnswer" => [false, true, false],
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]},
                      %{"nodes" => [%{"text" => "Option 3"}]}
                    ]
                  }
                }
              ]
            }
          },
          resource_summaries: [],
          transformed_model: nil
        }
      ]

      [choice1, choice2, choice3] =
        ActivityHelpers.stage_performance_details(
          activities,
          %{adaptive_id => %{slug: "oli_adaptive", title: "Adaptive"}},
          [],
          %{
            {63, "part_mcq"} => %{
              responses: [
                %{
                  activity_id: 63,
                  part_id: "part_mcq",
                  response: "1",
                  count: 1,
                  correct_count: 1,
                  incorrect_count: 0,
                  partial_count: 0,
                  users: []
                },
                %{
                  activity_id: 63,
                  part_id: "part_mcq",
                  response: "2",
                  count: 1,
                  correct_count: 0,
                  incorrect_count: 1,
                  partial_count: 0,
                  users: []
                },
                %{
                  activity_id: 63,
                  part_id: "part_mcq",
                  response: "3",
                  count: 1,
                  correct_count: 0,
                  incorrect_count: 0,
                  partial_count: 1,
                  users: []
                }
              ],
              student_ids: MapSet.new([1, 2, 3]),
              first_attempt_student_ids: MapSet.new([1, 2, 3]),
              attempt_count: 3,
              correct_count: 1,
              first_attempt_count: 3,
              first_attempt_correct_count: 1
            }
          }
        )
        |> hd()
        |> Map.fetch!(:adaptive_input_summaries)
        |> hd()
        |> then(fn summary ->
          assert summary.visualization.native_key_note =~ "native correct option"
          Map.fetch!(summary.visualization, :choices)
        end)

      assert choice1.native_correct == false
      assert choice1.correctness == true
      assert choice2.native_correct == true
      assert choice2.correctness == false
      assert choice3.native_correct == false
      assert choice3.correctness == :partial
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

  describe "preview_render/6" do
    test "returns an adaptive screen iframe preview even without attempts" do
      page_revision = %{
        slug: "adaptive_page",
        resource_id: 10,
        content: %{"custom" => %{"defaultScreenWidth" => 800, "defaultScreenHeight" => 600}}
      }

      screen_revision = %{
        slug: "welcome_screen",
        resource_id: 11,
        activity_type_id: 99,
        content: %{"partsLayout" => []}
      }

      html =
        ActivityHelpers.preview_render(
          %Section{slug: "adaptive_section"},
          page_revision,
          screen_revision,
          %{99 => %{slug: "oli_adaptive", title: "Adaptive"}},
          1,
          %{}
        )

      assert html =~ "Loading screen preview..."

      assert html =~
               "/sections/adaptive_section/preview/page/adaptive_page/adaptive_screen/welcome_screen"

      assert html =~ "adaptive_section"
      assert html =~ "adaptive_page"
      assert html =~ "welcome_screen"
    end
  end

  describe "rendered_activity/1" do
    test "does not render manual outcome badges for automatically graded adaptive inputs" do
      html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 55,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Auto MCQ",
                part_id: "part_mcq",
                component_type: "Mcq",
                grading_mode: :automatic,
                grading_mode_label: "Automatically Graded",
                response_count: 2,
                student_count: 2,
                attempt_count: 2,
                first_attempt_pct: 1.0,
                all_attempt_pct: 1.0,
                grading_pending: false,
                visualization: %{
                  kind: :choice_distribution,
                  prompt: "Auto MCQ",
                  description: "Selected choice distribution",
                  summary: "Each bar shows how many learners selected that option.",
                  denominator_count: 2,
                  denominator_label: "responses",
                  choices: [
                    %{label: "Option 1", count: 2, ratio: 1.0, correctness: true}
                  ]
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      refute html =~ "Manual Correct"
      refute html =~ "Manual Incorrect"
      refute html =~ "Manual Partial"
    end

    test "renders tooltip copy for answer key and awarded credit badges" do
      html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 56,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Manual MCQ",
                part_id: "part_mcq",
                component_type: "Mcq",
                grading_mode: :manual,
                grading_mode_label: "Instructor Manual Grading",
                response_count: 2,
                student_count: 2,
                attempt_count: 2,
                first_attempt_pct: 0.5,
                all_attempt_pct: 0.5,
                grading_pending: false,
                visualization: %{
                  kind: :choice_distribution,
                  prompt: "Manual MCQ",
                  description: "Selected choice distribution",
                  summary: "Each bar shows how many learners selected that option.",
                  denominator_count: 2,
                  denominator_label: "responses",
                  choices: [
                    %{
                      label: "Option 1",
                      count: 1,
                      ratio: 0.5,
                      native_correct: true,
                      correctness: :partial
                    }
                  ]
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      assert html =~ "This badge marks the authored answer key for the input."

      assert html =~
               "Instructor grading awarded partial credit for submissions associated with this option."
    end

    test "renders adaptive coverage with only unique responders" do
      html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 54,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Short Text",
                part_id: "part_text",
                component_type: "Input Text",
                grading_mode: :automatic,
                grading_mode_label: "Automatically Graded",
                response_count: 2,
                student_count: 1,
                attempt_count: 2,
                coverage_response_label: "First Input Responses",
                coverage_response_count: 2,
                coverage_student_label: "Uniques Students",
                coverage_student_count: 1,
                coverage_attempt_label: "First Input Attempts",
                coverage_attempt_count: 2,
                first_attempt_pct: 0.5,
                all_attempt_pct: 0.5,
                grading_pending: false,
                visualization: %{
                  kind: :correctness_distribution,
                  prompt: "Short Text",
                  description: "Aggregate performance for this input",
                  summary: "Use the outcome breakdown to see performance."
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      assert html =~ "Response Coverage"
      assert html =~ "Uniques Students"
      refute html =~ "First Input Responses"
      refute html =~ "First Input Attempts"
    end

    test "renders adaptive choice distributions even when correctness metadata is missing" do
      html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 53,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Dropdown",
                part_id: "part_dropdown",
                component_type: "Dropdown",
                grading_mode: :manual,
                grading_mode_label: "Instructor Manual Grading",
                response_count: 2,
                student_count: 2,
                attempt_count: 2,
                first_attempt_pct: 0.0,
                all_attempt_pct: 0.0,
                grading_pending: false,
                visualization: %{
                  kind: :choice_distribution,
                  prompt: "Dropdown 1",
                  description: "Selected option distribution",
                  summary: "Each bar shows how many learners selected that option.",
                  denominator_count: 2,
                  denominator_label: "responses",
                  choices: [
                    %{label: "Option 1", count: 0, ratio: 0.0},
                    %{label: "Option 2", count: 2, ratio: 1.0}
                  ]
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      assert html =~ "Dropdown 1"
      assert html =~ "Option 1"
      assert html =~ "Option 2"
      assert html =~ "0 of 2 responses"
      assert html =~ "2 of 2 responses"
      assert html =~ "Bar width represents the share of responses for this input."
    end

    test "renders adaptive response-pattern and numeric visualizations" do
      response_pattern_html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 57,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Formula",
                part_id: "part_formula",
                component_type: "Formula",
                grading_mode: :automatic,
                grading_mode_label: "Automatically Graded",
                response_count: 4,
                student_count: 4,
                attempt_count: 4,
                first_attempt_pct: 0.5,
                all_attempt_pct: 0.5,
                grading_pending: false,
                coverage_student_label: "Uniques Students",
                coverage_student_count: 4,
                visualization: %{
                  kind: :response_patterns,
                  prompt: "Formula",
                  description: "Most common submitted formulas",
                  summary:
                    "Each bar shows how often learners submitted the same formula for this input.",
                  denominator_count: 4,
                  entries: [
                    %{label: "x+1", count: 3, ratio: 0.75},
                    %{label: "x+2", count: 1, ratio: 0.25}
                  ]
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      assert response_pattern_html =~ "Most common submitted formulas"
      assert response_pattern_html =~ "x+1"
      assert response_pattern_html =~ "3 of 4 responses"

      numeric_html =
        render_component(&ActivityHelpers.rendered_activity/1, %{
          activity: %{
            id: 58,
            revision: %{activity_type_id: 99},
            preview_rendered: "<div>preview</div>",
            adaptive_input_summaries: [
              %{
                label: "Number",
                part_id: "part_number",
                component_type: "Input Number",
                grading_mode: :automatic,
                grading_mode_label: "Automatically Graded",
                response_count: 4,
                student_count: 4,
                attempt_count: 4,
                first_attempt_pct: 0.5,
                all_attempt_pct: 0.5,
                grading_pending: false,
                coverage_student_label: "Uniques Students",
                coverage_student_count: 4,
                visualization: %{
                  kind: :numeric_distribution,
                  prompt: "Number Input",
                  description: "Ordered numeric response distribution",
                  summary: "Each bar shows how often learners submitted that numeric value.",
                  denominator_count: 4,
                  entries: [
                    %{label: "1", count: 2, ratio: 0.5},
                    %{label: "2", count: 1, ratio: 0.25},
                    %{label: "3", count: 1, ratio: 0.25}
                  ],
                  stats: [
                    %{label: "Minimum", value: "1"},
                    %{label: "Average", value: "1.75"},
                    %{label: "Maximum", value: "3"}
                  ]
                },
                outcome_buckets: []
              }
            ]
          },
          activity_types_map: %{99 => %{slug: "oli_adaptive"}}
        })

      assert numeric_html =~ "Ordered numeric response distribution"
      assert numeric_html =~ "Minimum"
      assert numeric_html =~ "Average"
      assert numeric_html =~ "1.75"
    end
  end
end
