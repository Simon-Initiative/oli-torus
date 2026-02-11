defmodule Oli.Delivery.Attempts.ActivityLifecycle.EvaluateTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Activities

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
    defp response(id, rule, score, correct \\ false) do
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
end
