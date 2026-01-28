defmodule OliWeb.Api.DirectedDiscussionControllerTest do
  use OliWeb.ConnCase

  import Ecto.Query
  import Oli.Factory

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussion
  alias Oli.Resources.Collaboration
  alias Oli.Activities
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Lti_1p3.Roles.ContextRoles

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

  defp setup_published_resources(section, page_revision, activity_revision) do
    project = section.base_project

    from(sr in Oli.Delivery.Sections.SectionResource,
      where: sr.section_id == ^section.id and sr.resource_id == ^page_revision.resource_id
    )
    |> Oli.Repo.delete_all()

    container_resource = insert(:resource)

    container_revision =
      insert(:revision,
        resource: container_resource,
        resource_type_id: ResourceType.id_for_container(),
        content: %{},
        children: [page_revision.resource_id]
      )

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource_id})

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: activity_revision.resource_id
    })

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id
      })

    author = hd(project.authors)

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: activity_revision.resource,
      revision: activity_revision,
      author: author
    })

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    section
  end

  defp get_latest_activity_attempt_any_state(section_id, user_id, resource_id) do
    Oli.Repo.one(
      from(aa in Core.ActivityAttempt,
        join: ra in Core.ResourceAttempt,
        on: ra.id == aa.resource_attempt_id,
        join: rac in Core.ResourceAccess,
        on: rac.id == ra.resource_access_id,
        left_join: aa2 in Core.ActivityAttempt,
        on:
          aa2.resource_id == ^resource_id and
            aa2.resource_attempt_id == ra.id and
            aa.attempt_number < aa2.attempt_number,
        where:
          aa.resource_id == ^resource_id and
            rac.user_id == ^user_id and
            rac.section_id == ^section_id and
            is_nil(aa2.id),
        order_by: [desc: ra.attempt_number, desc: aa.attempt_number],
        limit: 1,
        select: aa
      )
    )
  end

  defp setup_session(%{conn: conn}) do
    user = insert(:user)
    section = insert(:section)

    # Enroll user in section
    Oli.Delivery.Sections.enroll(user.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    # Set up LTI session
    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_user(user)

    {:ok, conn: conn, user: user, section: section}
  end

  describe "POST /api/v1/discussion/:section_slug/:resource_id" do
    setup [:setup_session]

    test "creates post and evaluates activity when requirements are met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision)

      conn =
        post(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}",
          %{
            "content" => "Test post message"
          }
        )

      assert %{"result" => "success", "post" => post} = json_response(conn, 200)
      assert post["content"] == "Test post message"

      # Wait for async task to complete by polling for the expected outcome
      Oli.TestHelpers.wait_until(
        fn ->
          latest_attempt =
            Core.get_latest_activity_attempt(section.id, user.id, activity_revision.resource_id)

          latest_attempt != nil && latest_attempt.lifecycle_state == :evaluated
        end,
        timeout: 2000
      )

      # Verify the outcome: activity was evaluated
      latest_attempt =
        Core.get_latest_activity_attempt(section.id, user.id, activity_revision.resource_id)

      assert latest_attempt.lifecycle_state == :evaluated
      assert latest_attempt.score == 1.0
      assert latest_attempt.out_of == 1.0
      assert latest_attempt.date_evaluated != nil
    end

    test "creates post but does not evaluate when requirements are not met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 2})

      setup = setup_activity_attempt(user, section, activity_revision)

      conn =
        post(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}",
          %{
            "content" => "Test post message"
          }
        )

      assert %{"result" => "success", "post" => _post} = json_response(conn, 200)

      # Give async task a moment to run (it should not evaluate since requirements not met)
      Process.sleep(100)

      # Verify the outcome: activity was NOT evaluated (only 1 post, need 2)
      latest_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert latest_attempt.lifecycle_state == :active
      assert latest_attempt.score == nil
    end

    test "returns error when user is not enrolled", %{
      conn: conn,
      section: section
    } do
      # Create a different user who is not enrolled
      other_user = insert(:user)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      conn =
        conn
        |> log_in_user(other_user)
        |> post(
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}",
          %{
            "content" => "Test post message"
          }
        )

      assert %{
               "result" => "failure",
               "error" => "User does not have permission to create a post."
             } =
               json_response(conn, 200)
    end
  end

  describe "DELETE /api/v1/discussion/:section_slug/:resource_id/:post_id" do
    setup [:setup_session]

    test "deletes post and resets activity when requirements are no longer met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup = setup_activity_attempt(user, section, activity_revision)

      # Publish resources so reset_activity can run (DeliveryResolver.from_resource_id)
      section = setup_published_resources(section, setup.page_revision, activity_revision)

      # Create a post first
      {:ok, post} =
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

      # Evaluate the activity (simulate meeting requirements)
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Verify it's evaluated
      updated_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert updated_attempt.lifecycle_state == :evaluated

      # Now delete the post
      conn =
        delete(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}/#{post.id}"
        )

      assert %{"result" => "success"} = json_response(conn, 200)

      # Wait for async task: a new attempt is created (original stays evaluated)
      Oli.TestHelpers.wait_until(
        fn ->
          latest =
            get_latest_activity_attempt_any_state(
              section.id,
              user.id,
              activity_revision.resource_id
            )

          latest != nil &&
            latest.attempt_guid != setup.activity_attempt.attempt_guid &&
            latest.lifecycle_state == :active
        end,
        timeout: 2000
      )

      # Original attempt stays evaluated
      original_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert original_attempt.lifecycle_state == :evaluated
      assert original_attempt.score == 1.0

      # New attempt is active
      new_attempt =
        get_latest_activity_attempt_any_state(section.id, user.id, activity_revision.resource_id)

      assert new_attempt.attempt_guid != setup.activity_attempt.attempt_guid
      assert new_attempt.lifecycle_state == :active
      assert new_attempt.score == nil
      assert new_attempt.date_evaluated == nil
    end

    test "deletes post but does not reset when requirements are still met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup = setup_activity_attempt(user, section, activity_revision)

      # Create two posts
      {:ok, post1} =
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
          content: %Collaboration.PostContent{message: "Post 1"}
        })

      {:ok, _post2} =
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
          content: %Collaboration.PostContent{message: "Post 2"}
        })

      # Evaluate the activity
      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Delete one post (still have 1, which meets minPosts: 1)
      conn =
        delete(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}/#{post1.id}"
        )

      assert %{"result" => "success"} = json_response(conn, 200)

      # Give async task a moment to run (it should not reset since requirements still met)
      Process.sleep(100)

      # Verify the outcome: activity is still evaluated
      still_evaluated =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert still_evaluated.lifecycle_state == :evaluated
      assert still_evaluated.score == 1.0
    end

    test "returns error when user does not own the post", %{
      conn: conn,
      section: section
    } do
      other_user = insert(:user)

      Oli.Delivery.Sections.enroll(other_user.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      # Create a post as another user
      {:ok, post} =
        Collaboration.create_post(%{
          status: :approved,
          user_id: other_user.id,
          section_id: section.id,
          resource_id: activity_revision.resource_id,
          annotated_resource_id: activity_revision.resource_id,
          annotated_block_id: nil,
          annotation_type: :none,
          anonymous: false,
          visibility: :public,
          content: %Collaboration.PostContent{message: "Other user's post"}
        })

      conn =
        delete(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}/#{post.id}"
        )

      assert %{
               "result" => "failure",
               "error" => "User does not have permission to delete this post."
             } =
               json_response(conn, 200)
    end
  end

  describe "GET /api/v1/discussion/:section_slug/:resource_id" do
    setup [:setup_session]

    test "gets discussion and evaluates activity when requirements are met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup_activity_attempt(user, section, activity_revision)

      # Create a post
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

      conn =
        get(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}"
        )

      assert %{"result" => "success", "posts" => posts, "current_user" => current_user_id} =
               json_response(conn, 200)

      assert length(posts) == 1
      assert posts |> hd() |> Map.get("content") == "Test post"
      assert current_user_id == user.id

      # Wait for async task to complete by polling for the expected outcome
      Oli.TestHelpers.wait_until(
        fn ->
          latest_attempt =
            Core.get_latest_activity_attempt(section.id, user.id, activity_revision.resource_id)

          latest_attempt != nil && latest_attempt.lifecycle_state == :evaluated
        end,
        timeout: 2000
      )

      # Verify the outcome: activity was evaluated
      latest_attempt =
        Core.get_latest_activity_attempt(section.id, user.id, activity_revision.resource_id)

      assert latest_attempt.lifecycle_state == :evaluated
      assert latest_attempt.score == 1.0
    end

    test "gets discussion and resets activity when requirements are no longer met", %{
      conn: conn,
      user: user,
      section: section
    } do
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      setup = setup_activity_attempt(user, section, activity_revision)

      # Publish resources so reset_activity can run (DeliveryResolver.from_resource_id)
      section = setup_published_resources(section, setup.page_revision, activity_revision)

      # Create and evaluate activity first
      {:ok, post} =
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

      assert {:ok, :evaluated} =
               DirectedDiscussion.evaluate_if_requirements_met(
                 section.slug,
                 section.id,
                 activity_revision.resource_id,
                 user.id
               )

      # Delete the post (requirements no longer met)
      Collaboration.delete_posts(post)

      # Get discussion (should trigger create-new-attempt check)
      conn =
        get(
          conn,
          ~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}"
        )

      assert %{"result" => "success", "posts" => posts} = json_response(conn, 200)
      assert length(posts) == 0

      # Wait for async task: a new attempt is created (original stays evaluated)
      Oli.TestHelpers.wait_until(
        fn ->
          latest =
            get_latest_activity_attempt_any_state(
              section.id,
              user.id,
              activity_revision.resource_id
            )

          latest != nil &&
            latest.attempt_guid != setup.activity_attempt.attempt_guid &&
            latest.lifecycle_state == :active
        end,
        timeout: 2000
      )

      # Original attempt stays evaluated
      original_attempt =
        Core.get_activity_attempt_by(attempt_guid: setup.activity_attempt.attempt_guid)

      assert original_attempt.lifecycle_state == :evaluated
      assert original_attempt.score == 1.0

      # New attempt is active
      new_attempt =
        get_latest_activity_attempt_any_state(section.id, user.id, activity_revision.resource_id)

      assert new_attempt.attempt_guid != setup.activity_attempt.attempt_guid
      assert new_attempt.lifecycle_state == :active
      assert new_attempt.score == nil
    end

    test "returns error when user is not enrolled", %{
      conn: conn,
      section: section
    } do
      other_user = insert(:user)
      activity_revision = create_directed_discussion_activity(%{"minPosts" => 1})

      conn =
        conn
        |> log_in_user(other_user)
        |> get(~p"/api/v1/discussion/#{section.slug}/#{activity_revision.resource_id}")

      assert %{
               "result" => "failure",
               "error" => "User does not have permission to view these posts."
             } =
               json_response(conn, 200)
    end
  end
end
