defmodule Oli.Delivery.Attempts.ActivityLifecycle.EvaluateTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.ActivityLifecycle.AdaptivePartEvaluation
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Activities

  defmodule StubRuleEvaluator do
    @behaviour Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator

    @impl true
    def evaluate(state, rules, scoring_context) do
      matched_rules =
        Enum.filter(rules, fn rule ->
          rule_enabled?(rule) and rule_matches?(rule, state)
        end)

      {score, out_of} = screen_score(matched_rules, scoring_context)

      {:ok,
       %{
         "results" => Enum.map(matched_rules, &rule_event/1),
         "score" => score,
         "out_of" => out_of
       }}
    end

    defp rule_enabled?(rule) do
      field(rule, "disabled") != true
    end

    defp rule_matches?(rule, state) do
      if field(rule, "default") == true do
        true
      else
        case field(rule, "conditions") do
          %{"all" => conditions} when is_list(conditions) ->
            Enum.all?(conditions, &condition_matches?(&1, state))

          _ ->
            false
        end
      end
    end

    defp condition_matches?(
           %{"fact" => fact, "operator" => "equal", "value" => value},
           state
         ) do
      comparable(Map.get(state, fact)) == comparable(value)
    end

    defp condition_matches?(
           %{"fact" => fact, "operator" => "notEqual", "value" => value},
           state
         ) do
      comparable(Map.get(state, fact)) != comparable(value)
    end

    defp condition_matches?(_, _state), do: false

    defp comparable(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> int
        _ -> value
      end
    end

    defp comparable(value), do: value

    defp screen_score(matched_rules, %{trapStateScoreScheme: true, maxScore: max_score}) do
      case Enum.find_value(matched_rules, &current_question_score_value/1) do
        nil -> inferred_rule_score(matched_rules, max_score, true)
        score -> {score, max_score}
      end
    end

    defp screen_score(
           matched_rules,
           %{
             maxScore: max_score,
             maxAttempt: max_attempt,
             currentAttemptNumber: current_attempt_number
           } = scoring_context
         ) do
      inferred_rule_score(
        matched_rules,
        max_score,
        Map.get(scoring_context, :negativeScoreAllowed, false),
        max_attempt,
        current_attempt_number
      )
    end

    defp inferred_rule_score(matched_rules, max_score, _trap_state_score_scheme)
         when is_number(max_score) and max_score > 0 do
      inferred_rule_score(matched_rules, max_score, false, 1, 1)
    end

    defp inferred_rule_score(
           matched_rules,
           max_score,
           negative_score_allowed,
           max_attempt,
           current_attempt_number
         )
         when is_number(max_score) and max_score > 0 and is_number(max_attempt) and
                max_attempt > 0 do
      is_correct = Enum.any?(matched_rules, &rule_correct?/1)

      score =
        cond do
          is_correct or negative_score_allowed ->
            score_per_attempt = max_score / max_attempt
            max_score - score_per_attempt * (current_attempt_number - 1)

          matched_rules != [] ->
            0

          true ->
            nil
        end

      case score do
        nil -> {nil, nil}
        score -> {score * 1.0, max_score * 1.0}
      end
    end

    defp inferred_rule_score(
           _matched_rules,
           _max_score,
           _negative_score_allowed,
           _max_attempt,
           _current_attempt_number
         ),
         do: {nil, nil}

    defp rule_correct?(rule), do: field(rule, "correct") == true

    defp current_question_score_value(rule),
      do: current_question_score_value_from_event(rule_event(rule))

    defp current_question_score_value_from_event(%{"params" => %{"actions" => actions}})
         when is_list(actions) do
      Enum.find_value(actions, fn action ->
        with "mutateState" <- Map.get(action, "type"),
             "session.currentQuestionScore" <- get_in(action, ["params", "target"]),
             value when not is_nil(value) <- get_in(action, ["params", "value"]) do
          comparable(value)
        else
          _ -> nil
        end
      end)
    end

    defp current_question_score_value_from_event(_), do: nil

    defp rule_event(rule), do: field(rule, "event") || %{}

    defp field(rule, key) when is_map(rule) do
      Map.get(rule, key) || Map.get(rule, String.to_atom(key))
    end
  end

  defmodule NilScoreRuleEvaluator do
    @behaviour Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator

    @impl true
    def evaluate(state, rules, _scoring_context) do
      matched_rules =
        Enum.filter(rules, fn rule ->
          not (field(rule, "disabled") || false) and
            ((field(rule, "default") || false) or matches_all_conditions?(rule, state))
        end)

      {:ok,
       %{
         "results" => Enum.map(matched_rules, &(field(&1, "event") || %{})),
         "score" => nil,
         "out_of" => nil
       }}
    end

    defp matches_all_conditions?(rule, state) do
      case field(rule, "conditions") do
        %{"all" => conditions} when is_list(conditions) ->
          Enum.all?(conditions, fn
            %{"fact" => fact, "operator" => "equal", "value" => value} ->
              compare(Map.get(state, fact)) == compare(value)

            %{"fact" => fact, "operator" => "notEqual", "value" => value} ->
              compare(Map.get(state, fact)) != compare(value)

            _ ->
              false
          end)

        _ ->
          false
      end
    end

    defp compare(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> int
        _ -> value
      end
    end

    defp compare(value), do: value

    defp field(rule, key) when is_map(rule) do
      Map.get(rule, key) || Map.get(rule, String.to_atom(key))
    end
  end

  defp create_activity_with_type(activity_type_slug, content) do
    activity_resource = insert(:resource)

    activity_type =
      case Activities.get_registration_by_slug(activity_type_slug) do
        nil -> raise "Activity type '#{activity_type_slug}' not found"
        registration -> registration
      end

    insert(:revision,
      resource: activity_resource,
      resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
      activity_type_id: activity_type.id,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("total"),
      content: content
    )
  end

  defp setup_activity_attempt(user, section, activity_revision, opts \\ []) do
    # Create a page revision that contains the activity
    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => activity_revision.resource_id
            }
          ]
        },
        graded: Keyword.get(opts, :graded, false)
      )

    # Create SectionResource to link section and page
    insert(:section_resource,
      section: section,
      resource_id: page_resource.id,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      batch_scoring: false
    )

    resource_access =
      insert(:resource_access,
        user: user,
        section: section,
        resource: page_resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        attempt_number: Keyword.get(opts, :attempt_number, 1)
      )

    activity_attempt =
      %Core.ActivityAttempt{
        attempt_guid: Ecto.UUID.generate(),
        attempt_number: Keyword.get(opts, :activity_attempt_number, 1),
        resource_id: activity_revision.resource_id,
        revision_id: activity_revision.id,
        resource_attempt_id: resource_attempt.id,
        lifecycle_state: Keyword.get(opts, :lifecycle_state, :active),
        score: Keyword.get(opts, :score),
        out_of: Keyword.get(opts, :out_of),
        date_evaluated: Keyword.get(opts, :date_evaluated),
        date_submitted: Keyword.get(opts, :date_submitted),
        scoreable: true
      }
      |> Oli.Repo.insert!()
      |> Oli.Repo.preload([:revision, :resource_attempt])

    part_attempt =
      insert(:part_attempt,
        activity_attempt: activity_attempt,
        part_id: "1",
        lifecycle_state: Keyword.get(opts, :part_lifecycle_state, :active)
      )

    %{
      user: user,
      section: section,
      activity_revision: activity_revision,
      page_revision: page_revision,
      resource_access: resource_access,
      resource_attempt: resource_attempt,
      activity_attempt: activity_attempt,
      part_attempt: part_attempt
    }
  end

  defp setup_adaptive_activity_attempt(user, section, activity_revision, part_ids, opts \\ []) do
    setup = setup_activity_attempt(user, section, activity_revision, opts)

    Oli.Repo.delete!(setup.part_attempt)

    part_attempts =
      Enum.map(part_ids, fn part_id ->
        insert(:part_attempt,
          activity_attempt: setup.activity_attempt,
          part_id: part_id,
          lifecycle_state: Keyword.get(opts, :part_lifecycle_state, :active)
        )
      end)

    Map.put(setup, :part_attempts, part_attempts)
  end

  describe "evaluate_activity/4 - activity type specialization routing" do
    test "routes to DirectedDiscussion.evaluate_activity for oli_directed_discussion activities" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_directed_discussion", %{
          "participation" => %{"minPosts" => 1},
          "authoring" => %{
            "parts" => [
              %{
                "id" => "1",
                "responses" => [],
                "scoringStrategy" => "best",
                "evaluationStrategy" => "regex"
              }
            ]
          }
        })

      setup = setup_activity_attempt(user, section, activity_revision)

      # Create a post to meet requirements
      alias Oli.Resources.Collaboration

      {:ok, _post} =
        Collaboration.create_post(%{
          status: :approved,
          user_id: user.id,
          section_id: section.id,
          resource_id: activity_revision.resource_id,
          annotated_resource_id: activity_revision.resource_id,
          annotated_block_id: nil,
          annotation_type: :none,
          anonymous: false,
          visibility: :public,
          content: %Collaboration.PostContent{message: "Test post"}
        })

      # Call evaluate_activity - it should route to DirectedDiscussion
      assert {:ok, results} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 [],
                 nil
               )

      # Verify evaluation results were returned
      assert is_list(results)

      # Verify the activity attempt was evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated
      assert updated_attempt.score == 1.0
      assert updated_attempt.out_of == 1.0
      assert updated_attempt.date_evaluated != nil
    end

    test "continues with standard evaluation for non-specialized activity types" do
      user = insert(:user)
      section = insert(:section)

      # Create a multiple choice activity (not specialized)
      activity_revision =
        create_activity_with_type("oli_multiple_choice", %{
          "stem" => "What is 2+2?",
          "authoring" => %{
            "parts" => [
              %{
                "id" => "1",
                "responses" => [
                  %{
                    "id" => "r1",
                    "rule" => "input like {4}",
                    "score" => 1,
                    "correct" => true,
                    "feedback" => %{"id" => "1", "content" => "Correct!"}
                  },
                  %{
                    "id" => "r2",
                    "rule" => "input like {.*}",
                    "score" => 0,
                    "correct" => false,
                    "feedback" => %{"id" => "2", "content" => "Incorrect"}
                  }
                ],
                "scoringStrategy" => "best",
                "evaluationStrategy" => "regex"
              }
            ]
          }
        })

      setup = setup_activity_attempt(user, section, activity_revision)

      # Call evaluate_activity with part inputs - should use standard evaluation
      part_inputs = [
        %{
          attempt_guid: setup.part_attempt.attempt_guid,
          input: %StudentInput{input: "4"},
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, results} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      # Verify evaluation results were returned
      assert is_list(results)
      assert length(results) > 0

      # Verify the activity attempt was evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated
      assert updated_attempt.score != nil
      assert updated_attempt.date_evaluated != nil
    end

    test "returns error for non-existent activity attempt" do
      section = insert(:section)
      fake_guid = Ecto.UUID.generate()

      assert {:error, _reason} =
               Evaluate.evaluate_activity(section.slug, fake_guid, [], nil)
    end
  end

  describe "evaluate_from_input/5 - custom scoring repair" do
    defp response(id, rule, score, correct) do
      %{
        "id" => id,
        "rule" => rule,
        "score" => score,
        "correct" => correct,
        "feedback" => %{"id" => "f-#{id}", "content" => []}
      }
    end

    test "uses part outOf / targeted max to avoid inflated out_of when correct response is low" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_short_answer", %{
          "authoring" => %{
            "targeted" => [[["dummy"], "t2"]],
            "parts" => [
              %{
                "id" => "1",
                "outOf" => 4,
                "responses" => [
                  response("c1", "input like {a}", 1, true),
                  response("i1", "input like {.*}", 0, false)
                ]
              },
              %{
                "id" => "2",
                "outOf" => 4,
                "responses" => [
                  response("c2", "input like {b}", 1, true),
                  response("t2", "input like {b2}", 4, false),
                  response("i2", "input like {.*}", 0, false)
                ]
              }
            ]
          }
        })

      setup =
        setup_activity_attempt(user, section, activity_revision, out_of: 8.0, graded: true)

      part_attempt_2 =
        insert(:part_attempt,
          activity_attempt: setup.activity_attempt,
          part_id: "2",
          lifecycle_state: :active
        )

      part_inputs = [
        %{attempt_guid: setup.part_attempt.attempt_guid, input: %StudentInput{input: "a"}},
        %{attempt_guid: part_attempt_2.attempt_guid, input: %StudentInput{input: "b"}}
      ]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          setup.activity_attempt.attempt_guid,
          part_inputs,
          nil
        )

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 8.0
      assert updated_attempt.out_of == 8.0
    end
  end

  describe "calculate_manual_max_score/1" do
    test "sums manual part out_of values and treats nil as zero" do
      part_attempts = [
        build(:part_attempt, out_of: nil),
        build(:part_attempt, out_of: 2),
        build(:part_attempt, out_of: 3.5)
      ]

      assert Evaluate.calculate_manual_max_score(part_attempts) == 5.5
    end
  end

  describe "evaluate_activity/4 - adaptive automatic input-first scoring" do
    setup do
      previous_rule_evaluator = Application.get_env(:oli, :rule_evaluator)

      Application.put_env(
        :oli,
        :rule_evaluator,
        previous_rule_evaluator
        |> Keyword.new()
        |> Keyword.put(:dispatcher, StubRuleEvaluator)
      )

      on_exit(fn ->
        Application.put_env(:oli, :rule_evaluator, previous_rule_evaluator)
      end)

      :ok
    end

    test "resolves adaptive part attempts by part_id when attempt_guid is not present on the input" do
      activity_model = %{
        "partsLayout" => [
          %{
            "id" => "dropdown_1",
            "type" => "janus-dropdown",
            "custom" => %{
              "correctAnswer" => 2,
              "correctFeedback" => "Correct",
              "incorrectFeedback" => "Incorrect"
            }
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "gradingApproach" => "automatic"
            }
          ],
          "rules" => []
        }
      }

      part_attempt = %Core.PartAttempt{attempt_guid: "attempt-guid-1", part_id: "dropdown_1"}

      result =
        AdaptivePartEvaluation.evaluate(
          activity_model,
          [],
          %{maxScore: 1, maxAttempt: 1, trapStateScoreScheme: false, isManuallyGraded: false},
          %{
            "stage.dropdown_1.selectedIndex" => 2,
            "stage.dropdown_1.selectedItem" => "Option 2",
            "stage.dropdown_1.value" => "Option 2"
          },
          [
            %{
              part_id: "dropdown_1",
              attempt_guid: "missing-attempt-guid",
              input: %StudentInput{
                input: %{
                  "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
                  "selectedItem" => %{
                    "path" => "stage.dropdown_1.selectedItem",
                    "value" => "Option 2"
                  },
                  "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
                }
              }
            }
          ],
          [part_attempt]
        )

      assert result.score == 1.0
      assert result.out_of == 1.0

      assert [
               %{
                 attempt_guid: "attempt-guid-1",
                 client_evaluation: %{
                   score: 1.0,
                   out_of: 1.0
                 }
               }
             ] = result.client_evaluations
    end

    test "uses rule-driven screen scoring while keeping part-level scores independent" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"],
                "correctFeedback" => "First correct",
                "incorrectFeedback" => "First incorrect"
              }
            },
            %{
              "id" => "dropdown_2",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 1,
                "optionLabels" => ["Option A", "Option B"],
                "correctFeedback" => "Second correct",
                "incorrectFeedback" => "Second incorrect"
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => [
              "stage.dropdown_1.selectedIndex",
              "stage.dropdown_2.selectedIndex"
            ],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              },
              %{
                "id" => "dropdown_2",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              },
              %{
                "id" => "r.incorrect",
                "name" => "incorrect",
                "disabled" => false,
                "default" => false,
                "correct" => false,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "notEqual",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.incorrect",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1",
          "dropdown_2"
        ])

      [dropdown_1_attempt, dropdown_2_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_1_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: dropdown_2_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_2.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_2.selectedItem",
                "value" => "Option B"
              },
              "value" => %{"path" => "stage.dropdown_2.value", "value" => "Option B"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 2.0
      assert result["out_of"] == 2.0

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 2.0
      assert updated_attempt.out_of == 2.0

      updated_part_attempts =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)
        |> Enum.sort_by(& &1.part_id)

      [updated_dropdown_1, updated_dropdown_2] = updated_part_attempts

      assert updated_dropdown_1.score == 1.0
      assert updated_dropdown_1.out_of == 1.0
      assert updated_dropdown_1.lifecycle_state == :evaluated

      assert updated_dropdown_2.score == 0.0
      assert updated_dropdown_2.out_of == 1.0
      assert updated_dropdown_2.lifecycle_state == :evaluated
    end

    test "finalizes automatic adaptive inputs even when the screen also contains manual inputs" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"],
                "correctFeedback" => "Auto correct",
                "incorrectFeedback" => "Auto incorrect"
              }
            },
            %{
              "id" => "essay_1",
              "type" => "janus-multi-line-text",
              "custom" => %{
                "correctFeedback" => "Manual correct",
                "incorrectFeedback" => "Manual incorrect"
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => [
              "stage.dropdown_1.selectedIndex",
              "stage.essay_1.text"
            ],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              },
              %{
                "id" => "essay_1",
                "type" => "janus-multi-line-text",
                "gradingApproach" => "manual"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => true,
                "correct" => true,
                "conditions" => %{"all" => []},
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1",
          "essay_1"
        ])

      [dropdown_attempt, essay_attempt] =
        setup.part_attempts
        |> Enum.sort_by(& &1.part_id)

      assert {:ok, essay_attempt} =
               Core.update_part_attempt(essay_attempt, %{grading_approach: :manual})

      part_inputs = [
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: essay_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "text" => %{"path" => "stage.essay_1.text", "value" => "Needs instructor review"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, _result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :submitted
      assert updated_attempt.score == nil
      assert updated_attempt.out_of == nil

      updated_part_attempts =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)
        |> Enum.sort_by(& &1.part_id)

      [updated_dropdown, updated_essay] = updated_part_attempts

      assert updated_dropdown.grading_approach == :automatic
      assert updated_dropdown.lifecycle_state == :evaluated
      assert updated_dropdown.score == 1.0
      assert updated_dropdown.out_of == 1.0

      assert updated_essay.grading_approach == :manual
      assert updated_essay.lifecycle_state == :submitted
      assert updated_essay.score == nil
      assert updated_essay.out_of == nil
    end

    test "uses a single-input scorable rule to set part score, out_of, and feedback" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 1,
                "optionLabels" => ["Option 1", "Option 2"],
                "correctFeedback" => "Native correct",
                "incorrectFeedback" => "Native incorrect"
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.dropdown_1.selectedIndex"],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic",
                "outOf" => 2
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "feedback",
                        "params" => %{
                          "feedback" => %{"id" => "rule-correct", "content" => "Rule correct"}
                        }
                      }
                    ]
                  }
                }
              },
              %{
                "id" => "r.incorrect",
                "name" => "incorrect",
                "disabled" => false,
                "default" => false,
                "correct" => false,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "notEqual",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.incorrect",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "feedback",
                        "params" => %{
                          "feedback" => %{
                            "id" => "rule-incorrect",
                            "content" => "Rule incorrect"
                          }
                        }
                      }
                    ]
                  }
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1"
        ])

      [dropdown_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 2.0
      assert result["out_of"] == 2.0

      [updated_part_attempt] =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert updated_part_attempt.score == 2.0
      assert updated_part_attempt.out_of == 2.0
      assert updated_part_attempt.feedback["id"] == "rule-correct"
      assert updated_part_attempt.feedback["content"] == "Rule correct"
    end

    test "tracks explicitly rule-scored non-native parts and overrides them with the screen score" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "janus_capi_iframe-1",
              "type" => "janus-capi-iframe",
              "custom" => %{"title" => "Simulation"}
            },
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"],
                "correctFeedback" => "Dropdown correct",
                "incorrectFeedback" => "Dropdown incorrect"
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => [
              "stage.janus_capi_iframe-1.simScore",
              "stage.dropdown_1.selectedIndex"
            ],
            "parts" => [
              %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"},
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.janus_capi_iframe-1.simScore",
                      "operator" => "equal",
                      "value" => "100"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "feedback",
                        "params" => %{
                          "feedback" => %{
                            "id" => "screen-correct",
                            "content" => "Screen correct"
                          }
                        }
                      }
                    ]
                  }
                }
              },
              %{
                "id" => "r.incorrect",
                "name" => "incorrect",
                "disabled" => false,
                "default" => false,
                "correct" => false,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.janus_capi_iframe-1.simScore",
                      "operator" => "notEqual",
                      "value" => "100"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.incorrect",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "janus_capi_iframe-1",
          "dropdown_1"
        ])

      [iframe_attempt, dropdown_attempt] =
        setup.part_attempts
        |> Enum.sort_by(& &1.part_id)

      part_inputs = [
        %{
          attempt_guid: iframe_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "simScore" => %{
                "path" => "stage.janus_capi_iframe-1.simScore",
                "value" => 100
              },
              "status" => %{
                "path" => "stage.janus_capi_iframe-1.status",
                "value" => "passed"
              }
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 1},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 1"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 1"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 2.0
      assert result["out_of"] == 2.0

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 2.0
      assert updated_attempt.out_of == 2.0

      [updated_dropdown, updated_iframe] =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)
        |> Enum.sort_by(& &1.part_id)

      assert updated_dropdown.part_id == "dropdown_1"
      assert updated_dropdown.score == 0.0
      assert updated_dropdown.out_of == 1.0

      assert updated_iframe.part_id == "janus_capi_iframe-1"
      assert updated_iframe.score == 2.0
      assert updated_iframe.out_of == 2.0
      assert updated_iframe.feedback["id"] == "screen-correct"
      assert updated_iframe.feedback["content"] == "Screen correct"
    end

    test "falls back to generic feedback for rule-scored non-native parts when no screen feedback action is present" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 1, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "janus_capi_iframe-1",
              "type" => "janus-capi-iframe",
              "custom" => %{"title" => "Simulation"}
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.janus_capi_iframe-1.simScore"],
            "parts" => [
              %{"id" => "janus_capi_iframe-1", "type" => "janus-capi-iframe"}
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.janus_capi_iframe-1.simScore",
                      "operator" => "equal",
                      "value" => "100"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "navigation",
                        "params" => %{"target" => "next"}
                      }
                    ]
                  }
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "janus_capi_iframe-1"
        ])

      [iframe_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: iframe_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "simScore" => %{
                "path" => "stage.janus_capi_iframe-1.simScore",
                "value" => 100
              }
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 1.0
      assert result["out_of"] == 1.0

      [updated_iframe] = Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert updated_iframe.part_id == "janus_capi_iframe-1"
      assert updated_iframe.score == 1.0
      assert updated_iframe.out_of == 1.0
      assert is_binary(updated_iframe.feedback["id"])

      assert get_in(updated_iframe.feedback, ["content", "model", Access.at(0), "children"])
             |> List.first()
             |> Map.get("text") == "Correct"
    end

    test "uses a minimum screen out_of of 1 for adaptive screens with scorable inputs" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 0, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"]
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.dropdown_1.selectedIndex"],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1"
        ])

      [dropdown_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 1.0
      assert result["out_of"] == 1.0

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 1.0
      assert updated_attempt.out_of == 1.0

      [updated_part_attempt] =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert updated_part_attempt.score == 1.0
      assert updated_part_attempt.out_of == 1.0
    end

    test "falls back to rolled-up part scores when rules do not emit a screen score" do
      previous_rule_evaluator = Application.get_env(:oli, :rule_evaluator)

      Application.put_env(
        :oli,
        :rule_evaluator,
        previous_rule_evaluator
        |> Keyword.new()
        |> Keyword.put(:dispatcher, NilScoreRuleEvaluator)
      )

      on_exit(fn ->
        Application.put_env(:oli, :rule_evaluator, previous_rule_evaluator)
      end)

      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"]
              }
            },
            %{
              "id" => "dropdown_2",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 1,
                "optionLabels" => ["Option A", "Option B"]
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => [
              "stage.dropdown_1.selectedIndex",
              "stage.dropdown_2.selectedIndex"
            ],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              },
              %{
                "id" => "dropdown_2",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1",
          "dropdown_2"
        ])

      [dropdown_1_attempt, dropdown_2_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_1_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: dropdown_2_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_2.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_2.selectedItem",
                "value" => "Option B"
              },
              "value" => %{"path" => "stage.dropdown_2.value", "value" => "Option B"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 1.0
      assert result["out_of"] == 2.0

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 1.0
      assert updated_attempt.out_of == 2.0
    end

    test "ignores non-scorable adaptive payload entries that do not have part attempts" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => 1, "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "audio-1",
              "type" => "janus-audio",
              "custom" => %{}
            },
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"]
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.dropdown_1.selectedIndex"],
            "parts" => [
              %{"id" => "audio-1", "type" => "janus-audio"},
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1"
        ])

      [dropdown_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: "audio-1",
          input: %StudentInput{
            input: %{
              "dummy" => %{"path" => "stage.audio-1.dummy", "value" => true}
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 1},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 1"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 1"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["out_of"] == 1.0

      [updated_part_attempt] =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert updated_part_attempt.part_id == "dropdown_1"
      assert updated_part_attempt.out_of == 1.0
    end

    test "normalizes authored string maxScore values before adaptive scoring" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{"maxScore" => "2", "maxAttempt" => 1},
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"],
                "correctFeedback" => "Correct",
                "incorrectFeedback" => "Incorrect"
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.dropdown_1.selectedIndex"],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{"actions" => []}
                }
              }
            ]
          }
        })

      setup = setup_adaptive_activity_attempt(user, section, activity_revision, ["dropdown_1"])
      [dropdown_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 2.0
      assert result["out_of"] == 2.0

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 2.0
      assert updated_attempt.out_of == 2.0
    end

    test "respects explicit screen score mutations without overwriting part-level scores" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_activity_with_type("oli_adaptive", %{
          "custom" => %{
            "maxScore" => 10,
            "maxAttempt" => 1,
            "trapStateScoreScheme" => true
          },
          "partsLayout" => [
            %{
              "id" => "dropdown_1",
              "type" => "janus-dropdown",
              "custom" => %{
                "correctAnswer" => 2,
                "optionLabels" => ["Option 1", "Option 2"]
              }
            }
          ],
          "authoring" => %{
            "activitiesRequiredForEvaluation" => [],
            "variablesRequiredForEvaluation" => ["stage.dropdown_1.selectedIndex"],
            "parts" => [
              %{
                "id" => "dropdown_1",
                "type" => "janus-dropdown",
                "gradingApproach" => "automatic"
              }
            ],
            "rules" => [
              %{
                "id" => "r.correct",
                "name" => "correct",
                "disabled" => false,
                "default" => false,
                "correct" => true,
                "conditions" => %{
                  "all" => [
                    %{
                      "fact" => "stage.dropdown_1.selectedIndex",
                      "operator" => "equal",
                      "value" => "2"
                    }
                  ]
                },
                "event" => %{
                  "type" => "r.correct",
                  "params" => %{
                    "actions" => [
                      %{
                        "type" => "mutateState",
                        "params" => %{
                          "target" => "session.currentQuestionScore",
                          "operator" => "=",
                          "value" => "10"
                        }
                      }
                    ]
                  }
                }
              }
            ]
          }
        })

      setup =
        setup_adaptive_activity_attempt(user, section, activity_revision, [
          "dropdown_1"
        ])

      [dropdown_attempt] = setup.part_attempts

      part_inputs = [
        %{
          attempt_guid: dropdown_attempt.attempt_guid,
          input: %StudentInput{
            input: %{
              "selectedIndex" => %{"path" => "stage.dropdown_1.selectedIndex", "value" => 2},
              "selectedItem" => %{
                "path" => "stage.dropdown_1.selectedItem",
                "value" => "Option 2"
              },
              "value" => %{"path" => "stage.dropdown_1.value", "value" => "Option 2"}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      assert {:ok, result} =
               Evaluate.evaluate_activity(
                 section.slug,
                 setup.activity_attempt.attempt_guid,
                 part_inputs,
                 nil
               )

      assert result["score"] == 10
      assert result["out_of"] == 10

      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10

      [updated_part_attempt] =
        Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert updated_part_attempt.score == 1.0
      assert updated_part_attempt.out_of == 1.0
    end

    test "falls back to authored fill-blanks answers when runtime correct is absent" do
      activity_model = %{
        "custom" => %{"maxScore" => 1, "maxAttempt" => 1},
        "partsLayout" => [
          %{
            "id" => "fib_1",
            "type" => "janus-fill-blanks",
            "custom" => %{
              "caseSensitiveAnswers" => true,
              "alternateCorrectDelimiter" => ",",
              "elements" => [
                %{
                  "key" => "blank1",
                  "type" => "dropdown",
                  "correct" => "Option 1",
                  "alternateCorrect" => ["Option Uno"],
                  "options" => [
                    %{"key" => "Option 1", "value" => "Option 1"},
                    %{"key" => "Option 2", "value" => "Option 2"}
                  ]
                }
              ]
            }
          }
        ],
        "authoring" => %{
          "parts" => [
            %{"id" => "fib_1", "type" => "janus-fill-blanks", "gradingApproach" => "automatic"}
          ],
          "rules" => []
        }
      }

      scoring_context = %{maxScore: 1, trapStateScoreScheme: false, isManuallyGraded: false}
      state = %{"stage.fib_1.Input 1.Value" => "Option 1"}

      part_inputs = [
        %{
          attempt_guid: "fib-attempt-1",
          input: %StudentInput{
            input: %{
              "Input 1.Value" => %{
                "path" => "stage.fib_1.Input 1.Value",
                "value" => "Option 1"
              }
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      part_attempts = [
        %Core.PartAttempt{attempt_guid: "fib-attempt-1", part_id: "fib_1"}
      ]

      result =
        AdaptivePartEvaluation.evaluate(
          activity_model,
          [],
          scoring_context,
          state,
          part_inputs,
          part_attempts
        )

      assert result.score == 1.0
      assert result.out_of == 1.0
      assert result.correct

      [client_result] = result.client_evaluations
      assert client_result.attempt_guid == "fib-attempt-1"
      assert client_result.client_evaluation.score == 1.0
      assert client_result.client_evaluation.out_of == 1.0
    end

    test "honors exact and range-based numeric correctness for adaptive number inputs" do
      activity_model = %{
        "custom" => %{"maxScore" => 2, "maxAttempt" => 1},
        "partsLayout" => [
          %{
            "id" => "number_1",
            "type" => "janus-input-number",
            "custom" => %{
              "answer" => %{"range" => false, "correctAnswer" => 42},
              "correctFeedback" => "Correct!",
              "incorrectFeedback" => "Incorrect"
            }
          },
          %{
            "id" => "slider_1",
            "type" => "janus-slider",
            "custom" => %{
              "answer" => %{"range" => true, "correctMin" => 10, "correctMax" => 20},
              "correctFeedback" => "Correct!",
              "incorrectFeedback" => "Incorrect"
            }
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "number_1",
              "type" => "janus-input-number",
              "gradingApproach" => "automatic"
            },
            %{"id" => "slider_1", "type" => "janus-slider", "gradingApproach" => "automatic"}
          ],
          "rules" => []
        }
      }

      scoring_context = %{maxScore: 2, trapStateScoreScheme: false, isManuallyGraded: false}

      state = %{
        "stage.number_1.value" => 42,
        "stage.slider_1.value" => 15
      }

      part_inputs = [
        %{
          attempt_guid: "number-attempt-1",
          input: %StudentInput{
            input: %{
              "value" => %{"path" => "stage.number_1.value", "value" => 42}
            }
          },
          timestamp: DateTime.utc_now()
        },
        %{
          attempt_guid: "slider-attempt-1",
          input: %StudentInput{
            input: %{
              "value" => %{"path" => "stage.slider_1.value", "value" => 15}
            }
          },
          timestamp: DateTime.utc_now()
        }
      ]

      part_attempts = [
        %Core.PartAttempt{attempt_guid: "number-attempt-1", part_id: "number_1"},
        %Core.PartAttempt{attempt_guid: "slider-attempt-1", part_id: "slider_1"}
      ]

      result =
        AdaptivePartEvaluation.evaluate(
          activity_model,
          [],
          scoring_context,
          state,
          part_inputs,
          part_attempts
        )

      assert result.score == 2.0
      assert result.out_of == 2.0
      assert result.correct

      assert Enum.map(result.client_evaluations, & &1.client_evaluation.score) == [1.0, 1.0]
      assert Enum.map(result.client_evaluations, & &1.client_evaluation.out_of) == [1.0, 1.0]
    end
  end
end
