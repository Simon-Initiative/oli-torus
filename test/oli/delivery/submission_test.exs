defmodule Oli.Delivery.AttemptsSubmissionTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ActivityAttempt, PartAttempt, StudentInput}
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  defp setup_concurrent_activity(_) do
    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {b}",
                "score" => 1,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {c}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", max_attempts: 5, content: content}, :activity1)
      |> Seeder.add_activity(%{title: "two", max_attempts: 5, content: content}, :activity2)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)

    Seeder.ensure_published(map.publication.id)

    Seeder.add_page(
      map,
      %{
        title: "graded page",
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity1).revision.resource_id
            },
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity2).revision.resource_id
            }
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
        graded: true
      },
      :container,
      :graded_page
    )
    |> Seeder.create_section_resources()
  end

  describe "concurrent activity accesses with two students" do
    setup [:setup_tags, :setup_concurrent_activity]

    @tag isolation: "serializable"
    test "graded page : determine_resource_attempt_state works with 2 users after user1 has started a page and user2 has not",
         %{
           graded_page: %{resource: resource, revision: revision},
           user1: user1,
           user2: user2,
           section: section
         } do
      datashop_session_id_user1 = UUID.uuid4()
      datashop_session_id_user2 = UUID.uuid4()

      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user2.id, section.id, [ContextRoles.get_role(:context_learner)])

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user1.id)

      # Open the graded page as user 1 to get the prologue
      user1_page_context =
        PageContext.create_for_visit(section, revision.slug, user1, datashop_session_id_user1)

      assert user1_page_context.progress_state == :not_started
      assert Enum.empty?(user1_page_context.resource_attempts)

      # Start the attempt and go into the assessment
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6

      {:ok,
       %Oli.Delivery.Attempts.PageLifecycle.AttemptState{
         resource_attempt: user1_resource_attempt,
         attempt_hierarchy: user1_activity_attempts
       }} =
        PageLifecycle.start(
          revision.slug,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )

      # Save an activity part on the page but do not submit it
      {:ok, %{num_rows: 1}} =
        ActivityLifecycle.save_student_input([
          %{
            # attempt_guid: user1_part_attempt.attempt_guid,
            attempt_guid:
              user1_activity_attempts
              |> Map.values()
              |> hd
              |> elem(1)
              |> Map.values()
              |> hd
              |> Map.get(:attempt_guid),
            response: %{input: "a"}
          }
        ])

      # Make sure the latest resource attempt is still correct
      user1_latest_resource_attempt =
        Attempts.get_latest_resource_attempt(resource.id, section.slug, user1.id)

      assert user1_latest_resource_attempt.id == user1_resource_attempt.id

      # Make sure the progress state is correct for the latest resource attempt
      assert PageContext.create_for_visit(
               section,
               revision.slug,
               user1,
               datashop_session_id_user1
             ).progress_state ==
               :in_progress

      # Now we have an "in progress" resource attempt for student 1 with a saved student input,
      # so the resource is partially completed.

      # User 2

      # Access the graded page with user2
      assert is_nil(Attempts.get_latest_resource_attempt(resource.id, section.slug, user2.id))

      user2_page_context =
        PageContext.create_for_visit(section, revision.slug, user2, datashop_session_id_user2)

      assert user2_page_context.progress_state == :not_started
      assert Enum.empty?(user2_page_context.resource_attempts)

      {:ok,
       %Oli.Delivery.Attempts.PageLifecycle.AttemptState{
         resource_attempt: user2_resource_attempt,
         attempt_hierarchy: user2_activity_attempts
       }} =
        PageLifecycle.start(
          revision.slug,
          section.slug,
          datashop_session_id_user2,
          user2,
          effective_settings,
          activity_provider
        )

      # Save attempts for both activities
      ActivityLifecycle.save_student_input([
        %{
          attempt_guid:
            user2_activity_attempts
            |> Map.values()
            |> hd
            |> elem(1)
            |> Map.values()
            |> hd
            |> Map.get(:attempt_guid),
          response: %{input: "a"}
        }
      ])

      ActivityLifecycle.save_student_input([
        %{
          attempt_guid:
            user2_activity_attempts
            |> Map.values()
            |> tl
            |> hd
            |> elem(1)
            |> Map.values()
            |> hd
            |> Map.get(:attempt_guid),
          response: %{input: "a"}
        }
      ])

      # Make sure user 2 can submit the page
      {:ok, %FinalizationSummary{resource_access: access}} =
        PageLifecycle.finalize(
          section.slug,
          user2_resource_attempt.attempt_guid,
          datashop_session_id_user2
        )

      access = Repo.preload(access, [:resource_attempts])

      assert !is_nil(hd(access.resource_attempts).date_evaluated)
    end
  end

  describe "resetting an activity" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(%{title: "one", content: content}, :activity)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(
        map,
        %{
          title: "page1",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
          max_attempts: 2
        },
        :ungraded_page
      )
      |> Seeder.add_page(
        %{
          title: "page2",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
          graded: true
        },
        :graded_page
      )
      |> Seeder.create_section_resources()

      # Ungraded page ("page1" / :page1) attempts
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity_attempt1,
        :ungraded_page_user1_activity_attempt1_part1_attempt1
      )

      # Graded page ("page2" / :graded_page) attempts
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page,
        :graded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :graded_page_user1_attempt1,
        :user1_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :user1_activity_attempt1,
        :user1_part1_attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user2,
        :graded_page,
        :graded_page_user2_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :graded_page_user2_attempt1,
        :user2_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :user2_activity_attempt1,
        :user2_part1_attempt1
      )
    end

    test "ungraded page: get_latest_resource_attempt gives an unevaluated attempt with 1 user", %{
      ungraded_page: %{resource: resource},
      user1: user1,
      section: section,
      ungraded_page_user1_attempt1: resource_attempt1
    } do
      resource_attempt = Attempts.get_latest_resource_attempt(resource.id, section.slug, user1.id)

      assert resource_attempt.id == resource_attempt1.id
      assert is_nil(resource_attempt.date_evaluated)
      assert is_nil(resource_attempt.score)
    end

    test "Graded page: get_latest_resource_attempt gives the correct resource attempts with 2 users",
         %{
           graded_page: %{resource: resource},
           user1: user1,
           user2: user2,
           section: section,
           graded_page_user1_attempt1: resource_attempt1,
           graded_page_user2_attempt1: resource_attempt2
         } do
      resource_attempt_user1 =
        Attempts.get_latest_resource_attempt(resource.id, section.slug, user1.id)

      resource_attempt_user2 =
        Attempts.get_latest_resource_attempt(resource.id, section.slug, user2.id)

      assert resource_attempt1.id == resource_attempt_user1.id
      assert resource_attempt2.id == resource_attempt_user2.id

      assert resource_attempt1.id != resource_attempt2.id
    end

    test "determine_resource_attempt_state works for graded pages with 1 user", %{
      graded_page: %{revision: revision},
      user1: user1,
      section: section,
      user1_part1_attempt1: part_attempt,
      user1_activity_attempt1: activity_attempt,
      graded_page_user1_attempt1: resource_attempt1
    } do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id_user1 = UUID.uuid4()
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user1.id)

      # User1 has a started resource attempt, so it should be "in progress"
      {:ok, {:in_progress, _resource_attempt}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      # Evaluate the parts to allow the graded page to be submitted
      {:ok, _evals} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # Submit the page to toggle it from "in progress" to completed
      PageLifecycle.finalize(
        section.slug,
        resource_attempt1.attempt_guid,
        datashop_session_id_user1
      )

      # determine_resource_attempt_state should no longer retrieve the previously in progress attempt
      {:ok, {:not_started, _resource_attempt}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )
    end

    test "parts can only be submitted once", %{
      graded_page: %{revision: revision},
      user1: user1,
      section: section,
      user1_part1_attempt1: part_attempt,
      user1_activity_attempt1: activity_attempt
    } do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id_user1 = UUID.uuid4()
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user1.id)

      {:ok, {:in_progress, _resource_attempt}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, _evals} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      {:ok, []} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )
    end

    test "determine_resource_attempt_state works for graded pages with 2 users when user1 submits a page and user2 submits submits it afterwards",
         %{
           graded_page: %{revision: revision},
           user1: user1,
           section: section,
           user1_part1_attempt1: user1_part1_attempt1,
           user2_part1_attempt1: user2_part1_attempt1,
           user1_activity_attempt1: user1_activity_attempt,
           user2_activity_attempt1: user2_activity_attempt,
           graded_page_user1_attempt1: user1_resource_attempt1,
           graded_page_user2_attempt1: user2_resource_attempt1,
           user2: user2
         } do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id_user1 = UUID.uuid4()
      datashop_session_id_user2 = UUID.uuid4()

      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user1.id)

      # User 1
      {:ok, {:in_progress, resource_attempt_user1}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )

      part_inputs = [
        %{attempt_guid: user1_part1_attempt1.attempt_guid, input: %StudentInput{input: "a"}}
      ]

      {:ok, _evals} =
        Evaluate.evaluate_from_input(
          section.slug,
          user1_activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      PageLifecycle.finalize(
        section.slug,
        user1_resource_attempt1.attempt_guid,
        datashop_session_id_user1
      )

      {:ok, {:not_started, _resource_attempt}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user1,
          user1,
          effective_settings,
          activity_provider
        )

      Sections.enroll(user2.id, section.id, [ContextRoles.get_role(:context_learner)])

      # User 2
      {:ok, {:in_progress, resource_attempt_user2}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user2,
          user2,
          effective_settings,
          activity_provider
        )

      # Make sure we're looking at a different resource attempt for the second user
      assert resource_attempt_user1 != resource_attempt_user2

      part_inputs = [
        %{attempt_guid: user2_part1_attempt1.attempt_guid, input: %StudentInput{input: "a"}}
      ]

      {:ok, _evals} =
        Evaluate.evaluate_from_input(
          section.slug,
          user2_activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user2
        )

      PageLifecycle.finalize(
        section.slug,
        user2_resource_attempt1.attempt_guid,
        datashop_session_id_user2
      )

      {:ok, {:not_started, _resource_attempt}} =
        PageLifecycle.visit(
          revision,
          section.slug,
          datashop_session_id_user2,
          user2,
          effective_settings,
          activity_provider
        )

      # verify that the submitted part attempts have the correct datashop session id
      # corresponding to the user who submitted them
      updated_user1_part1_attempt1 = Core.get_part_attempt_by(id: user1_part1_attempt1.id)
      updated_user2_part1_attempt1 = Core.get_part_attempt_by(id: user2_part1_attempt1.id)
      assert updated_user1_part1_attempt1.datashop_session_id == datashop_session_id_user1
      assert updated_user2_part1_attempt1.datashop_session_id == datashop_session_id_user2
    end

    # this is the function that saves an input in a graded assessment before the page is submitted
    test "can save student inputs and receive a count", %{user1_part1_attempt1: part_attempt} do
      part_inputs = [
        %{
          attempt_guid: part_attempt.attempt_guid,
          response: %{input: "a"}
        }
      ]

      # The part can be saved once
      assert {:ok, %{num_rows: 1}} = ActivityLifecycle.save_student_input(part_inputs)
      # The part can be saved again
      assert {:ok, %{num_rows: 1}} = ActivityLifecycle.save_student_input(part_inputs)
    end

    test "processing a submission", %{
      activity: %{revision: activity_revision},
      ungraded_page: %{revision: page_revision},
      user1: user,
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      section: section,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id = UUID.uuid4()
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id
        )

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission rolled up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10.0
      assert updated_attempt.out_of == 10.0
      refute updated_attempt.date_evaluated == nil

      # now reset the activity
      {:ok, {attempt_state, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity_attempt.attempt_guid,
          datashop_session_id
        )

      assert attempt_state.dateEvaluated == nil
      assert attempt_state.score == nil
      assert attempt_state.outOf == nil
      assert length(attempt_state.parts) == 1
      assert hd(attempt_state.parts).response == nil
      assert attempt_state.hasMoreAttempts == false

      # now try to reset when there are no more attempts
      assert {:error, {:no_more_attempts}} ==
               ActivityLifecycle.reset_activity(
                 section.slug,
                 attempt_state.attemptGuid,
                 datashop_session_id
               )

      # verify that a snapshot record was created properly
      [%Snapshot{} = snapshot] = Oli.Repo.all(Snapshot)

      assert snapshot.score == 10
      assert snapshot.out_of == 10
      assert snapshot.graded == false
      assert snapshot.part_attempt_id == part_attempt.id
      assert snapshot.part_attempt_number == 1
      assert snapshot.attempt_number == 1
      assert snapshot.resource_attempt_number == 1
      assert snapshot.section_id == section.id
      assert snapshot.user_id == user.id
      assert snapshot.activity_id == updated_attempt.resource_id
      assert snapshot.resource_id == page_revision.resource_id
      assert snapshot.revision_id == activity_revision.id

      # verify that the submitted part attempt has the latest datashop session id
      updated_part_attempt = Core.get_part_attempt_by(id: part_attempt.id)
      assert updated_part_attempt.datashop_session_id == datashop_session_id
    end

    test "processing a submission where there are invalid scores", %{
      graded_page_user1_attempt1: resource_attempt1,
      user1_part1_attempt1: part_attempt,
      section: section,
      user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission rolled up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10.0
      assert updated_attempt.out_of == 10.0
      refute updated_attempt.date_evaluated == nil

      # Now simulate something having gone wrong, perhaps a rogue activity using
      # client-side eval, or some other future bug in the system leading to an invalid
      # score for the activity attempt

      Attempts.update_activity_attempt(updated_attempt, %{score: 2.0, out_of: 1.0})

      PageLifecycle.finalize(
        section.slug,
        resource_attempt1.attempt_guid,
        datashop_session_id_user1
      )

      # Verify a valid grade was recorded despite the invalid grade at the activity attempt
      ra = Oli.Repo.get(ResourceAccess, resource_attempt1.resource_access_id)
      assert ra.score == 1.0
      assert ra.out_of == 1.0
    end

    test "handling reset attempts that request preservation of last attempt state", %{
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      section: section,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()

      # submit activity with a known state for the part attempt
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # now reset the activity, requesting seed_state_from_previous to be true
      {:ok, {%{parts: [part_attempt]}, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity_attempt.attempt_guid,
          datashop_session_id_user1,
          true
        )

      assert part_attempt.response == %{"input" => "a", "files" => nil}
    end

    # This test case ensures that the following scenario works correctly:
    #
    # 1. Student opens a resource with an activity that has a maximum of TWO attempts in window tab A.
    # 2. Student submits a response (exhausting attempt 1).
    # 3. Student opens a new window tab B with the same resource. This generates a new activity attempt (attempt 2)
    # 4. Student submits a response for tab B. (exhausting attempt 2)
    # 5. Student clicks "Reset" in tab A.  This should be rejected.
    test "handling concurrent reset attempts", %{
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      section: section,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()

      # Submit in tab A:
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # now reset the activity, this is a simulation of the student
      # opening the resource in tab B.
      {:ok, {attempt_state, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity_attempt.attempt_guid,
          datashop_session_id_user1
        )

      assert attempt_state.hasMoreAttempts == false

      # now try to reset the guid from the first attempt, simulating the
      # student clicking 'Reset' in tab A.
      assert {:error, {:no_more_attempts}} ==
               ActivityLifecycle.reset_activity(
                 section.slug,
                 activity_attempt.attempt_guid,
                 datashop_session_id_user1
               )

      # verify that the reset activity part attempt has the latest datashop session id
      updated_part_attempt = Core.get_part_attempt_by(id: part_attempt.id)
      assert updated_part_attempt.datashop_session_id == datashop_session_id_user1
    end
  end

  describe "processing a one part submission" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(%{title: "one", content: content}, :activity)
        |> Seeder.add_user(%{}, :user1)

      Seeder.ensure_published(map.publication.id)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity).revision.resource_id
            }
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.add_page(map, attrs, :ungraded_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity_attempt1,
        :ungraded_page_user1_activity_attempt1_part1_attempt1
      )
    end

    test "processing a submission", %{
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      section: section,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()

      # assert the part attempt does not start with the latest datashop session id
      assert part_attempt.datashop_session_id != datashop_session_id_user1

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission rolled up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10.0
      assert updated_attempt.out_of == 10.0
      refute updated_attempt.date_evaluated == nil

      # verify that the updated part attempt has the latest datashop session id
      updated_part_attempt = Core.get_part_attempt_by(id: part_attempt.id)
      assert updated_part_attempt.datashop_session_id == datashop_session_id_user1
    end

    test "processing a different submission", %{
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      section: section,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "b"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      assert attempt_guid == part_attempt.attempt_guid
      assert score == 1
      assert out_of == 10
      assert id == "2"
    end

    test "processing a submission whose input matches no response", %{
      section: section,
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "d"}}]

      # No matching response should mark the answer as incorrect with out_of
      # being the highest score of any response considered.
      {:ok, [%{feedback: %{id: _id}, score: 0, out_of: 10}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )
    end
  end

  describe "processing a multipart submission" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            },
            %{
              "id" => "2",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 2,
                  "id" => "r1",
                  "feedback" => %{"id" => "4", "content" => "yes"}
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "5", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "6", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(
          %{title: "one", content: content},
          :publication,
          :project,
          :author,
          :activity
        )
        |> Seeder.add_user(%{}, :user1)

      Seeder.ensure_published(map.publication.id)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity).revision.resource_id
            }
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.add_page(map, attrs, :ungraded_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity_attempt1,
        :ungraded_page_user1_activity_attempt1_part1_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "2", responses: [], hints: []},
        :ungraded_page_user1_activity_attempt1,
        :ungraded_page_user1_activity_attempt1_part2_attempt1
      )
    end

    test "processing a submission with just one of the parts submitted", %{
      section: section,
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission did NOT roll up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == nil
      assert updated_attempt.out_of == nil
      assert updated_attempt.date_evaluated == nil

      # verify that we can reset that part attempt
      {:ok, partState} =
        ActivityLifecycle.reset_part(activity_attempt.attempt_guid, attempt_guid, UUID.uuid4())

      new_attempt = Oli.Repo.get_by!(PartAttempt, attempt_guid: partState.attemptGuid)
      assert new_attempt.score == nil
      assert new_attempt.out_of == nil
      assert new_attempt.date_evaluated == nil
      refute new_attempt.attempt_guid == updated_attempt.attempt_guid
      assert new_attempt.attempt_number == 2
      assert new_attempt.activity_attempt_id == activity_attempt.id

      # and submit again against the new attempt
      part_inputs = [%{attempt_guid: new_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}}]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      assert attempt_guid == new_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, new_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil
    end

    test "processing a submission with all parts submitted", %{
      section: section,
      ungraded_page_user1_activity_attempt1_part1_attempt1: part_attempt,
      ungraded_page_user1_activity_attempt1_part2_attempt1: part2_attempt,
      ungraded_page_user1_activity_attempt1: activity_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()

      part_inputs = [
        %{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}},
        %{attempt_guid: part2_attempt.attempt_guid, input: %StudentInput{input: "b"}}
      ]

      {:ok,
       [
         %{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id}},
         %{attempt_guid: attempt_guid2, out_of: out_of2, score: score2, feedback: %{id: id2}}
       ]} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      assert attempt_guid2 == part2_attempt.attempt_guid
      assert score2 == 1
      assert out_of2 == 2
      assert id2 == "5"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      updated_attempt = Oli.Repo.get!(PartAttempt, part2_attempt.id)
      assert updated_attempt.score == 1
      assert updated_attempt.out_of == 2
      refute updated_attempt.date_evaluated == nil

      # verify that the submission did roll up to the activity attempt
      # with the fact that the scoring strategy defaults to best
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10.0
      assert updated_attempt.out_of == 10.0
      refute updated_attempt.date_evaluated == nil
    end
  end
end
