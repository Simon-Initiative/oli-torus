defmodule Oli.Delivery.Attempts.CoreTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.CustomLogs.CustomActivityLog
  alias Oli.Repo
  alias Oli.Resources.ScoringStrategy

  describe "delete_resource_attempt/1" do
    setup do
      admin_author =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)

      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      revision =
        insert(:revision,
          resource: resource,
          graded: true,
          scoring_strategy_id: ScoringStrategy.get_id_by_type("average")
        )

      resource_access =
        insert(:resource_access,
          user: user,
          section: section,
          resource: resource,
          score: 4.0,
          out_of: 5.0
        )

      resource_attempt =
        insert(:resource_attempt,
          resource_access: resource_access,
          revision: revision,
          attempt_number: 1
        )

      activity_attempt =
        insert(:activity_attempt,
          resource_attempt: resource_attempt,
          resource: resource,
          revision: revision
        )

      part_attempt = insert(:part_attempt, activity_attempt: activity_attempt)

      %{
        admin_author: admin_author,
        user: user,
        resource_access: resource_access,
        revision: revision,
        resource_attempt: resource_attempt,
        activity_attempt: activity_attempt,
        part_attempt: part_attempt
      }
    end

    test "deletes the attempt hierarchy and clears the sole attempt score", ctx do
      assert {:ok, %ResourceAccess{score: nil, out_of: nil}} =
               Core.delete_resource_attempt(
                 ctx.resource_attempt.attempt_guid,
                 nil,
                 ctx.admin_author
               )

      refute Repo.get(ResourceAttempt, ctx.resource_attempt.id)
      refute Repo.get(ActivityAttempt, ctx.activity_attempt.id)
      refute Repo.get(PartAttempt, ctx.part_attempt.id)

      assert %{score: nil, out_of: nil} = Repo.get!(ResourceAccess, ctx.resource_access.id)
    end

    test "rejects deletion from a non-system-admin actor", ctx do
      assert {:error, :unauthorized} =
               Core.delete_resource_attempt(ctx.resource_attempt.attempt_guid, nil, ctx.user)

      assert Repo.get(ResourceAttempt, ctx.resource_attempt.id)
    end

    test "returns not found for a missing attempt", ctx do
      assert {:error, :not_found} =
               Core.delete_resource_attempt("missing-attempt-guid", nil, ctx.admin_author)
    end

    test "deletes custom activity logs associated with the attempt", ctx do
      log =
        %CustomActivityLog{}
        |> CustomActivityLog.changeset(%{
          resource_id: ctx.resource_access.resource_id,
          user_id: ctx.resource_access.user_id,
          section_id: ctx.resource_access.section_id,
          activity_attempt_id: ctx.activity_attempt.id,
          revision_id: ctx.revision.id,
          activity_type: "test",
          attempt_number: 1,
          action: "test",
          info: "test"
        })
        |> Repo.insert!()

      assert {:ok, _} =
               Core.delete_resource_attempt(
                 ctx.resource_attempt.attempt_guid,
                 nil,
                 ctx.admin_author
               )

      refute Repo.get(CustomActivityLog, log.id)
    end

    test "recalculates the resource access score when the latest attempt is deleted", ctx do
      first_attempt =
        Repo.update!(
          ResourceAttempt.changeset(ctx.resource_attempt, %{
            lifecycle_state: :evaluated,
            score: 2.0,
            out_of: 5.0
          })
        )

      second_attempt =
        insert(:resource_attempt,
          resource_access: ctx.resource_access,
          revision: ctx.revision,
          attempt_number: 2,
          lifecycle_state: :evaluated,
          score: 4.0,
          out_of: 5.0
        )

      assert {:ok, %ResourceAccess{score: 2.0, out_of: 5.0}} =
               Core.delete_resource_attempt(second_attempt.attempt_guid, nil, ctx.admin_author)

      assert Repo.get(ResourceAttempt, first_attempt.id)
      refute Repo.get(ResourceAttempt, second_attempt.id)
      assert %{score: 2.0, out_of: 5.0} = Repo.get!(ResourceAccess, ctx.resource_access.id)
    end

    test "rejects deleting an intermediate attempt", ctx do
      first_attempt =
        Repo.update!(
          ResourceAttempt.changeset(ctx.resource_attempt, %{
            lifecycle_state: :evaluated,
            score: 1.0,
            out_of: 5.0
          })
        )

      intermediate_attempt =
        insert(:resource_attempt,
          resource_access: ctx.resource_access,
          revision: ctx.revision,
          attempt_number: 2,
          lifecycle_state: :evaluated,
          score: 2.5,
          out_of: 5.0
        )

      latest_attempt =
        insert(:resource_attempt,
          resource_access: ctx.resource_access,
          revision: ctx.revision,
          attempt_number: 3,
          lifecycle_state: :evaluated,
          score: 5.0,
          out_of: 5.0
        )

      assert {:error, :not_latest} =
               Core.delete_resource_attempt(
                 intermediate_attempt.attempt_guid,
                 nil,
                 ctx.admin_author
               )

      assert Repo.get(ResourceAttempt, first_attempt.id)
      assert Repo.get(ResourceAttempt, intermediate_attempt.id)
      assert Repo.get(ResourceAttempt, latest_attempt.id)
    end

    test "recalculates average scoring from the remaining evaluated attempts", ctx do
      first_attempt =
        Repo.update!(
          ResourceAttempt.changeset(ctx.resource_attempt, %{
            lifecycle_state: :evaluated,
            score: 1.0,
            out_of: 5.0
          })
        )

      insert(:resource_attempt,
        resource_access: ctx.resource_access,
        revision: ctx.revision,
        attempt_number: 2,
        lifecycle_state: :evaluated,
        score: 2.5,
        out_of: 5.0
      )

      latest_attempt =
        insert(:resource_attempt,
          resource_access: ctx.resource_access,
          revision: ctx.revision,
          attempt_number: 3,
          lifecycle_state: :evaluated,
          score: 5.0,
          out_of: 5.0
        )

      assert {:ok, %ResourceAccess{score: 1.75, out_of: 5.0}} =
               Core.delete_resource_attempt(latest_attempt.attempt_guid, nil, ctx.admin_author)

      assert %{score: 1.75, out_of: 5.0} = Repo.get!(ResourceAccess, ctx.resource_access.id)
      assert Repo.get(ResourceAttempt, first_attempt.id)
    end

    test "recalculates most recent scoring from the remaining evaluated attempts", ctx do
      first_evaluated_at = ~U[2025-01-01 00:00:00Z]
      second_evaluated_at = ~U[2025-01-02 00:00:00Z]
      latest_evaluated_at = ~U[2025-01-03 00:00:00Z]

      Repo.update!(
        ResourceAttempt.changeset(ctx.resource_attempt, %{
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 5.0,
          date_evaluated: first_evaluated_at
        })
      )

      insert(:resource_attempt,
        resource_access: ctx.resource_access,
        revision: ctx.revision,
        attempt_number: 2,
        lifecycle_state: :evaluated,
        score: 2.5,
        out_of: 5.0,
        date_evaluated: second_evaluated_at
      )

      latest_attempt =
        insert(:resource_attempt,
          resource_access: ctx.resource_access,
          revision: ctx.revision,
          attempt_number: 3,
          lifecycle_state: :evaluated,
          score: 5.0,
          out_of: 5.0,
          date_evaluated: latest_evaluated_at
        )

      most_recent_strategy_id = ScoringStrategy.get_id_by_type("most_recent")

      assert {:ok, %ResourceAccess{score: 2.5, out_of: 5.0}} =
               Core.delete_resource_attempt(
                 latest_attempt.attempt_guid,
                 most_recent_strategy_id,
                 ctx.admin_author
               )
    end
  end

  describe "graded resource access functions" do
    setup do
      create_test_section_with_pages()
    end

    test "get_graded_resource_access_for_context/1 returns all graded resource access for a section",
         ctx do
      result = Core.get_graded_resource_access_for_context(ctx.section.id)

      # Should return 3 resource access records (2 for graded_page_1, 1 for graded_page_2)
      assert length(result) == 3

      # Verify all returned records are for graded pages
      resource_ids = Enum.map(result, & &1.resource_id)
      assert ctx.graded_page_1.id in resource_ids
      assert ctx.graded_page_2.id in resource_ids
      refute ctx.practice_page.id in resource_ids

      # Verify all returned records are for the correct section
      assert Enum.all?(result, &(&1.section_id == ctx.section.id))
    end

    test "get_graded_resource_access_for_context/2 filters by user IDs", ctx do
      user_ids = [ctx.user_1.id, ctx.user_2.id]
      result = Core.get_graded_resource_access_for_context(ctx.section.id, user_ids)

      # Should return 3 resource access records (2 for user_1, 1 for user_2)
      assert length(result) == 3

      # Verify all returned records are for the specified users
      user_ids_in_result = Enum.map(result, & &1.user_id)
      assert Enum.all?(user_ids_in_result, &(&1 in user_ids))

      # Verify all returned records are for graded pages
      resource_ids = Enum.map(result, & &1.resource_id)
      assert ctx.graded_page_1.id in resource_ids
      assert ctx.graded_page_2.id in resource_ids
      refute ctx.practice_page.id in resource_ids
    end

    test "get_graded_resource_access_for_context/2 with single user ID", ctx do
      user_ids = [ctx.user_1.id]
      result = Core.get_graded_resource_access_for_context(ctx.section.id, user_ids)

      # Should return 2 resource access records (1 for graded_page_1, 1 for graded_page_2)
      assert length(result) == 2

      # Verify all returned records are for the specified user
      assert Enum.all?(result, &(&1.user_id == ctx.user_1.id))

      # Verify all returned records are for graded pages
      resource_ids = Enum.map(result, & &1.resource_id)
      assert ctx.graded_page_1.id in resource_ids
      assert ctx.graded_page_2.id in resource_ids
      refute ctx.practice_page.id in resource_ids
    end

    test "get_graded_resource_access_for_context/2 with empty user IDs list", ctx do
      result = Core.get_graded_resource_access_for_context(ctx.section.id, [])

      # Should return empty list when no user IDs provided
      assert result == []
    end

    test "get_graded_resource_access_for_context/2 with non-existent user IDs", ctx do
      non_existent_user_id = 999_999
      result = Core.get_graded_resource_access_for_context(ctx.section.id, [non_existent_user_id])

      # Should return empty list when user IDs don't exist
      assert result == []
    end
  end

  describe "user retrieval from attempts" do
    setup do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      resource_access =
        insert(:resource_access, %{
          user: user,
          section: section,
          resource: resource
        })

      resource_attempt =
        insert(:resource_attempt, %{
          resource_access: resource_access,
          attempt_guid: "test-guid-123"
        })

      %{
        user: user,
        section: section,
        resource: resource,
        resource_access: resource_access,
        resource_attempt: resource_attempt
      }
    end

    test "get_user_from_attempt/1 retrieves user from resource attempt", ctx do
      result = Core.get_user_from_attempt(ctx.resource_attempt)

      assert result.id == ctx.user.id
      assert result.email == ctx.user.email
      assert result.name == ctx.user.name
    end

    test "get_user_from_attempt_guid/1 retrieves user from attempt GUID", ctx do
      result = Core.get_user_from_attempt_guid(ctx.resource_attempt.attempt_guid)

      assert result.id == ctx.user.id
      assert result.email == ctx.user.email
      assert result.name == ctx.user.name
    end

    test "get_user_from_attempt_guid/1 returns nil for non-existent GUID", _ctx do
      refute Core.get_user_from_attempt_guid("non-existent-guid")
    end
  end

  describe "attempt checking" do
    setup do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      resource_access =
        insert(:resource_access, %{
          user: user,
          section: section,
          resource: resource
        })

      %{
        user: user,
        section: section,
        resource: resource,
        resource_access: resource_access
      }
    end

    test "has_any_attempts?/3 returns true when attempts exist", ctx do
      # Create a resource attempt
      insert(:resource_attempt, %{
        resource_access: ctx.resource_access
      })

      assert Core.has_any_attempts?(ctx.user, ctx.section, ctx.resource.id)
    end

    test "has_any_attempts?/3 returns false when no attempts exist", ctx do
      refute Core.has_any_attempts?(ctx.user, ctx.section, ctx.resource.id)
    end

    test "has_any_resource_attempts?/2 returns true when any learner attempt exists", ctx do
      insert(:resource_attempt, %{
        resource_access: ctx.resource_access
      })

      assert Core.has_any_resource_attempts?(ctx.section, ctx.resource.id)
    end

    test "has_any_resource_attempts?/2 returns false when no learner attempts exist", ctx do
      refute Core.has_any_resource_attempts?(ctx.section, ctx.resource.id)
    end

    test "has_any_resource_accesses?/2 returns true when any learner access exists", ctx do
      assert Core.has_any_resource_accesses?(ctx.section, ctx.resource.id)
    end

    test "has_any_resource_accesses?/2 returns false when no learner accesses exist", ctx do
      other_resource = insert(:resource)

      refute Core.has_any_resource_accesses?(ctx.section, other_resource.id)
    end
  end

  describe "resource access retrieval" do
    setup do
      section = insert(:section)
      resource = insert(:resource)
      user = insert(:user)

      resource_access =
        insert(:resource_access, %{
          section: section,
          user: user,
          resource: resource
        })

      %{
        section: section,
        resource: resource,
        user: user,
        resource_access: resource_access
      }
    end

    test "get_resource_access/1 retrieves preloaded resource access", ctx do
      result = Core.get_resource_access(ctx.resource_access.id)

      assert result.id == ctx.resource_access.id
      assert result.section_id == ctx.section.id
      assert result.user_id == ctx.user.id
      assert result.resource_id == ctx.resource.id
    end

    test "get_resource_access/1 returns nil for non-existent ID", _ctx do
      refute Core.get_resource_access(999_999)
    end
  end

  # Helper function to create a test section with graded and practice pages
  defp create_test_section_with_pages do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create resources
    graded_page_1 = insert(:resource)
    graded_page_2 = insert(:resource)
    practice_page = insert(:resource)

    # Create revisions
    graded_revision_1 =
      insert(:revision, %{
        resource: graded_page_1,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        graded: true,
        title: "Graded Page 1"
      })

    graded_revision_2 =
      insert(:revision, %{
        resource: graded_page_2,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        graded: true,
        title: "Graded Page 2"
      })

    practice_revision =
      insert(:revision, %{
        resource: practice_page,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        graded: false,
        title: "Practice Page"
      })

    # Create a simple container structure
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [graded_page_1.id, graded_page_2.id, practice_page.id],
        title: "Test Container"
      })

    all_revisions = [graded_revision_1, graded_revision_2, practice_revision, container_revision]

    # Associate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # Publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id
      })

    # Publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # Create section
    section =
      insert(:section, %{
        base_project: project,
        title: "Test Section",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      })

    # Create section resources
    {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_pages(section)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_objectives(section)

    # Create users
    user_1 = insert(:user)
    user_2 = insert(:user)
    user_3 = insert(:user)

    # Create resource access records
    resource_access_1 =
      insert(:resource_access, %{
        section: section,
        user: user_1,
        resource: graded_page_1,
        access_count: 1
      })

    resource_access_2 =
      insert(:resource_access, %{
        section: section,
        user: user_2,
        resource: graded_page_1,
        access_count: 1
      })

    resource_access_3 =
      insert(:resource_access, %{
        section: section,
        user: user_1,
        resource: graded_page_2,
        access_count: 1
      })

    resource_access_4 =
      insert(:resource_access, %{
        section: section,
        user: user_3,
        resource: practice_page,
        access_count: 1
      })

    %{
      section: section,
      graded_page_1: graded_page_1,
      graded_page_2: graded_page_2,
      practice_page: practice_page,
      user_1: user_1,
      user_2: user_2,
      user_3: user_3,
      resource_access_1: resource_access_1,
      resource_access_2: resource_access_2,
      resource_access_3: resource_access_3,
      resource_access_4: resource_access_4
    }
  end
end
