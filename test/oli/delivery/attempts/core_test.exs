defmodule Oli.Delivery.Attempts.CoreTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Attempts.Core

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
