defmodule Oli.Delivery.Evaluation.ExplanationTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Delivery.Sections

  defp setup_explanation(_) do
    %{}
    |> Seeder.Project.create_author(author_tag: :author)
    |> Seeder.Project.create_sample_project(
      ref(:author),
      project_tag: :proj,
      publication_tag: :pub,
      unscored_page1_tag: :unscored_page1,
      unscored_page1_activity_tag: :unscored_page1_activity,
      scored_page2_tag: :scored_page2,
      scored_page2_activity_tag: :scored_page2_activity
    )
    |> Seeder.Project.ensure_published(ref(:pub))
    |> Seeder.Section.create_section(
      ref(:proj),
      ref(:pub),
      nil,
      %{},
      section_tag: :section
    )
    |> Seeder.Section.create_and_enroll_learner(
      ref(:section),
      %{},
      user_tag: :student1
    )
  end

  describe "explanation" do
    setup [:setup_tags, :setup_explanation]

    @tag isolation: "serializable"
    test "after_max_resource_attempts_exhausted strategy explanation in a scored page", map do
      datashop_session_id_user1 = UUID.uuid4()

      Sections.get_section_resource(map.section.id, map.scored_page2.resource_id)
      |> Sections.update_section_resource(%{
        max_attempts: 3
      })

      map =
        map
        |> Seeder.Project.set_revision_explanation_strategy(
          ref(:scored_page2),
          %ExplanationStrategy{
            type: :after_max_resource_attempts_exhausted
          }
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )

      # explanation strategy condition has not been met, evaluation should return normal feedback
      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: nil
                }
              ]} = map.scored_page2_activity_evaluation

      map =
        map
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )

      # explanation strategy condition met, evaluation should return explanation in feedback
      assert {
               :ok,
               [
                 %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                   type: "FeedbackAction",
                   error: nil,
                   feedback: %Oli.Activities.Model.Feedback{
                     content: %{
                       "model" => [
                         %{
                           "children" => [
                             %{"text" => "Incorrect"}
                           ],
                           "type" => "p"
                         }
                       ]
                     }
                   },
                   out_of: 10,
                   part_id: "1",
                   score: 0,
                   show_page: nil,
                   explanation: %Oli.Activities.Model.Explanation{
                     content: %{
                       "model" => [
                         %{
                           "children" => [%{"text" => "a scored activity explanation"}],
                           "type" => "p"
                         }
                       ]
                     }
                   }
                 }
               ]
             } = map.scored_page2_activity_evaluation
    end

    @tag isolation: "serializable"
    test "after_max_resource_attempts_exhausted strategy should not trigger when max_attempts is 0 (infinite)",
         map do
      datashop_session_id_user1 = UUID.uuid4()

      map =
        map
        |> Seeder.Project.set_revision_max_attempts(ref(:scored_page2), 0)
        |> Seeder.Project.set_revision_explanation_strategy(
          ref(:scored_page2),
          %ExplanationStrategy{
            type: :after_max_resource_attempts_exhausted
          }
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )

      # explanation strategy condition will never be met, evaluation should return normal feedback
      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: nil
                }
              ]} = map.scored_page2_activity_evaluation
    end

    @tag isolation: "serializable"
    test "after_set_num_attempts strategy explanation in a scored page", map do
      datashop_session_id_user1 = UUID.uuid4()

      map =
        map
        |> Seeder.Project.set_revision_explanation_strategy(
          ref(:scored_page2),
          %ExplanationStrategy{
            type: :after_set_num_attempts,
            set_num_attempts: 2
          }
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )

      # explanation strategy condition has not been met, evaluation should return normal feedback
      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: nil
                }
              ]} = map.scored_page2_activity_evaluation

      map =
        map
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page2),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page2_attempt,
          attempt_hierarchy_tag: :page2_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:scored_page2_activity),
          ref(:page2_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          evaluation_result_tag: :scored_page2_activity_evaluation
        )
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page2_attempt),
          datashop_session_id_user1
        )

      # explanation strategy condition met, evaluation should return explanation
      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: %Oli.Activities.Model.Explanation{
                    content: %{
                      "model" => [
                        %{
                          "children" => [%{"text" => "a scored activity explanation"}],
                          "type" => "p"
                        }
                      ]
                    }
                  }
                }
              ]} = map.scored_page2_activity_evaluation
    end

    test "after_set_num_attempts explanation strategy in an unscored page", map do
      datashop_session_id_user1 = UUID.uuid4()

      map =
        map
        |> Seeder.Project.set_revision_explanation_strategy(
          ref(:unscored_page1),
          %ExplanationStrategy{
            type: :after_set_num_attempts,
            set_num_attempts: 2
          }
        )
        |> Seeder.Attempt.visit_page(
          ref(:unscored_page1),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page1_attempt,
          attempt_hierarchy_tag: :page1_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:unscored_page1_activity),
          ref(:page1_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          activity_attempt_tag: :unscored_page1_activity_attempt,
          evaluation_result_tag: :unscored_page1_activity_evaluation
        )

      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: nil
                }
              ]} = map.unscored_page1_activity_evaluation

      map =
        map
        |> Seeder.Attempt.reset_activity(
          ref(:section),
          ref(:unscored_page1_activity_attempt),
          datashop_session_id_user1
        )
        |> Seeder.Attempt.visit_page(
          ref(:unscored_page1),
          ref(:section),
          ref(:student1),
          datashop_session_id_user1,
          resource_attempt_tag: :page1_attempt,
          attempt_hierarchy_tag: :page1_attempt_hierarchy
        )
        |> Seeder.Attempt.submit_attempt_for_activity(
          ref(:section),
          ref(:unscored_page1_activity),
          ref(:page1_attempt_hierarchy),
          fn %PartAttempt{} -> %StudentInput{input: "incorrect"} end,
          datashop_session_id_user1,
          activity_attempt_tag: :unscored_page1_activity_attempt,
          evaluation_result_tag: :unscored_page1_activity_evaluation
        )

      assert {:ok,
              [
                %Oli.Delivery.Evaluation.Actions.FeedbackAction{
                  type: "FeedbackAction",
                  error: nil,
                  feedback: %Oli.Activities.Model.Feedback{
                    content: %{
                      "model" => [
                        %{
                          "children" => [
                            %{"text" => "Incorrect"}
                          ],
                          "type" => "p"
                        }
                      ]
                    }
                  },
                  out_of: 10,
                  part_id: "1",
                  score: 0,
                  show_page: nil,
                  explanation: %Oli.Activities.Model.Explanation{
                    content: %{
                      "model" => [
                        %{
                          "children" => [%{"text" => "an unscored activity explanation"}],
                          "type" => "p"
                        }
                      ]
                    }
                  }
                }
              ]} = map.unscored_page1_activity_evaluation
    end
  end
end
