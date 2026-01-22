defmodule Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussion
  alias Oli.Delivery.Attempts.Core
  alias Oli.Resources.Collaboration
  alias Oli.Activities

  defp create_directed_discussion_activity(participation) do
    activity_resource = insert(:resource)

    activity_type =
      case Activities.get_registration_by_slug("oli_directed_discussion") do
        nil -> raise "oli_directed_discussion activity type not found"
        registration -> registration
      end

    content = %{
      "participation" => participation,
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
    }

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

  defp create_post(user, section, resource_id, message, parent_post_id \\ nil) do
    {:ok, post} =
      Collaboration.create_post(%{
        status: :approved,
        user_id: user.id,
        section_id: section.id,
        resource_id: resource_id,
        annotated_resource_id: resource_id,
        annotated_block_id: nil,
        annotation_type: :none,
        anonymous: false,
        visibility: :public,
        content: %Collaboration.PostContent{message: message},
        parent_post_id: parent_post_id
      })

    post
  end

  describe "check_participation_requirements/3" do
    test "returns false when no activity attempt exists" do
      user = insert(:user)
      section = insert(:section)

      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      assert {:ok, false} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns false when activity attempt is not active" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision, lifecycle_state: :evaluated)

      assert {:ok, false} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns true when minPosts requirement is met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision)

      # Create a post
      create_post(user, section, activity_revision.resource_id, "Test post")

      assert {:ok, true} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns false when minPosts requirement is not met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 2})

      setup_activity_attempt(user, section, activity_revision)

      # Create only one post (need 2)
      create_post(user, section, activity_revision.resource_id, "Test post")

      assert {:ok, false} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns true when minReplies requirement is met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minReplies" => 1})

      setup_activity_attempt(user, section, activity_revision)

      # Create a parent post
      parent_post = create_post(user, section, activity_revision.resource_id, "Parent post")

      # Create a reply
      create_post(user, section, activity_revision.resource_id, "Reply", parent_post.id)

      assert {:ok, true} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns false when minReplies requirement is not met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minReplies" => 2})

      setup_activity_attempt(user, section, activity_revision)

      # Create a parent post
      parent_post = create_post(user, section, activity_revision.resource_id, "Parent post")

      # Create only one reply (need 2)
      create_post(user, section, activity_revision.resource_id, "Reply", parent_post.id)

      assert {:ok, false} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns true when both minPosts and minReplies requirements are met" do
      user = insert(:user)
      section = insert(:section)

      activity_revision =
        create_directed_discussion_activity(%{"minPosts" => 1, "minReplies" => 1})

      setup_activity_attempt(user, section, activity_revision)

      # Create a post
      parent_post = create_post(user, section, activity_revision.resource_id, "Parent post")

      # Create a reply
      create_post(user, section, activity_revision.resource_id, "Reply", parent_post.id)

      assert {:ok, true} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns true when no requirements are specified (defaults to 0)" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{})

      setup_activity_attempt(user, section, activity_revision)

      assert {:ok, true} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns error when activity model cannot be retrieved" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      _setup = setup_activity_attempt(user, section, activity_revision)

      # Corrupt the revision content
      activity_revision
      |> Ecto.Changeset.change(content: nil)
      |> Oli.Repo.update!()

      assert {:error, "Could not retrieve activity model"} =
               DirectedDiscussion.check_participation_requirements(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end
  end

  describe "evaluate_if_requirements_met/5" do
    test "returns error when no activity attempt exists" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      assert {:error, "Activity attempt not found"} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns :already_evaluated when activity is already evaluated" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision, lifecycle_state: :evaluated)

      assert {:ok, :already_evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns :requirements_not_met when requirements are not met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 2})

      setup_activity_attempt(user, section, activity_revision)

      # Create only one post (need 2)
      create_post(user, section, activity_revision.resource_id, "Test post")

      assert {:ok, :requirements_not_met} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "evaluates activity when requirements are met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup = setup_activity_attempt(user, section, activity_revision)

      # Create a post to meet requirements
      create_post(user, section, activity_revision.resource_id, "Test post")

      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the activity attempt was evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated
      assert updated_attempt.score == 1.0
      assert updated_attempt.out_of == 1.0
      assert updated_attempt.date_evaluated != nil
    end

    test "evaluates activity with multiple part attempts" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup = setup_activity_attempt(user, section, activity_revision)

      # Create another part attempt
      insert(:part_attempt,
        activity_attempt: setup.activity_attempt,
        part_id: "2"
      )

      # Create a post to meet requirements
      create_post(user, section, activity_revision.resource_id, "Test post")

      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify all part attempts were evaluated
      part_attempts = Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert Enum.all?(part_attempts, fn pa -> pa.lifecycle_state == :evaluated end)
    end

    test "works with multiple page attempts (new resource attempt)" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      # First attempt
      _setup1 = setup_activity_attempt(user, section, activity_revision, attempt_number: 1)

      # Create a post
      create_post(user, section, activity_revision.resource_id, "Test post")

      # Evaluate first attempt
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Second attempt (new resource attempt)
      setup2 =
        setup_activity_attempt(user, section, activity_revision,
          attempt_number: 2,
          lifecycle_state: :active
        )

      # Should still evaluate because posts from previous attempts count
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the second attempt was evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup2.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated
    end
  end

  describe "reset_if_requirements_not_met/3" do
    test "returns error when no activity attempt exists" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      assert {:error, "Activity attempt not found"} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns :not_evaluated when activity is not evaluated" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision, lifecycle_state: :active)

      assert {:ok, :not_evaluated} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )
    end

    test "returns :requirements_met when requirements are still met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      # Create a post first
      create_post(user, section, activity_revision.resource_id, "Test post")

      setup =
        setup_activity_attempt(user, section, activity_revision,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0,
          date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:ok, :requirements_met} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the activity attempt is still evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated
    end

    test "resets activity when requirements are no longer met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup =
        setup_activity_attempt(user, section, activity_revision,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0,
          date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second),
          date_submitted: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      # Create and then delete the post (simulating deletion)
      post = create_post(user, section, activity_revision.resource_id, "Test post")
      Collaboration.delete_posts(post)

      assert {:ok, :reset} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the activity attempt was reset
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :active
      assert updated_attempt.score == nil
      assert updated_attempt.out_of == nil
      assert updated_attempt.date_evaluated == nil
      assert updated_attempt.date_submitted == nil

      # Verify part attempts were reset
      part_attempts = Core.get_latest_part_attempts(setup.activity_attempt.attempt_guid)

      assert Enum.all?(part_attempts, fn pa ->
               pa.lifecycle_state == :active and pa.date_evaluated == nil
             end)
    end

    test "resets activity when minPosts requirement is no longer met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 2})

      # Create three posts first to meet requirements
      post1 = create_post(user, section, activity_revision.resource_id, "Post 1")
      post2 = create_post(user, section, activity_revision.resource_id, "Post 2")
      create_post(user, section, activity_revision.resource_id, "Post 3")

      setup = setup_activity_attempt(user, section, activity_revision, lifecycle_state: :active)

      # Evaluate (requirements met)
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Delete one post (now only 2 posts, but need 2, so should still be met)
      Collaboration.delete_posts(post1)

      assert {:ok, :requirements_met} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Delete another post (now only 1 post, requirement not met)
      Collaboration.delete_posts(post2)

      assert {:ok, :reset} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the activity attempt was reset
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :active
    end

    test "resets activity when minReplies requirement is no longer met" do
      user = insert(:user)
      section = insert(:section)
      activity_revision = create_directed_discussion_activity(%{"minReplies" => 1})

      # Create a parent post and reply first
      parent_post = create_post(user, section, activity_revision.resource_id, "Parent")
      reply = create_post(user, section, activity_revision.resource_id, "Reply", parent_post.id)

      setup = setup_activity_attempt(user, section, activity_revision, lifecycle_state: :active)

      # Evaluate (requirements met)
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Delete the reply (requirement no longer met)
      Collaboration.delete_posts(reply)

      assert {:ok, :reset} =
               DirectedDiscussion.reset_if_requirements_not_met(
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify the activity attempt was reset
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :active
    end
  end
end
