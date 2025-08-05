defmodule Oli.Lti.PlatformExternalToolsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.BrowseOptions
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.ResourceType

  describe "browse_platform_instances/3" do
    import Oli.Factory

    setup do
      # Create platform instances with different names and descriptions
      platform_1 =
        insert(:platform_instance, %{
          name: "AAA Tool",
          description: "First tool",
          client_id: "client_id_1"
        })

      platform_2 =
        insert(:platform_instance, %{
          name: "BBB Tool",
          description: "Second tool",
          client_id: "client_id_2"
        })

      platform_3 =
        insert(:platform_instance, %{
          name: "CCC Tool",
          description: "Third tool",
          client_id: "client_id_3"
        })

      # Create deployments for each platform instance
      deployment_1 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform_1,
          status: :enabled
        })

      deployment_2 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform_2,
          status: :disabled
        })

      deployment_3 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform_3,
          status: :enabled
        })

      %{
        platform_1: platform_1,
        platform_2: platform_2,
        platform_3: platform_3,
        deployment_1: deployment_1,
        deployment_2: deployment_2,
        deployment_3: deployment_3
      }
    end

    test "browse with default options returns all enabled instances", %{
      platform_1: platform_1,
      platform_3: platform_3
    } do
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: false}
        )

      assert length(results) == 2
      assert Enum.map(results, & &1.name) == [platform_1.name, platform_3.name]
    end

    test "browse with include_disabled returns all instances", %{
      platform_1: platform_1,
      platform_2: platform_2,
      platform_3: platform_3
    } do
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert length(results) == 3
      assert Enum.map(results, & &1.name) == [platform_1.name, platform_2.name, platform_3.name]
    end

    test "browse with text search filters by name", %{platform_2: platform_2} do
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{text_search: "BBB", include_disabled: true}
        )

      assert length(results) == 1
      assert hd(results).name == platform_2.name
    end

    test "browse with text search filters by description", %{platform_3: platform_3} do
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{text_search: "Third", include_disabled: true}
        )

      assert length(results) == 1
      assert hd(results).description == platform_3.description
    end

    test "browse respects pagination", %{platform_1: platform_1, platform_2: platform_2} do
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 2},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert length(results) == 2
      assert Enum.map(results, & &1.name) == [platform_1.name, platform_2.name]

      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 2, limit: 2},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert length(results) == 1
    end

    test "browse sorts by different fields", %{
      platform_1: platform_1,
      platform_2: platform_2,
      platform_3: platform_3
    } do
      # Test sorting by name desc
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :desc},
          %BrowseOptions{include_disabled: true}
        )

      assert Enum.map(results, & &1.name) == [platform_3.name, platform_2.name, platform_1.name]

      # Test sorting by description asc
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :description, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert Enum.map(results, & &1.description) == [
               platform_1.description,
               platform_2.description,
               platform_3.description
             ]

      # Test sorting by status
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :status, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert Enum.map(results, & &1.status) == [:disabled, :enabled, :enabled]
    end

    test "browse includes soft deleted tools depending on include_deleted options value", %{
      platform_1: platform_1,
      platform_2: platform_2,
      platform_3: platform_3,
      deployment_2: deployment_2
    } do
      # Soft delete platform_2 tool
      PlatformExternalTools.update_lti_external_tool_activity_deployment(
        deployment_2,
        %{"status" => :deleted}
      )

      # Should NOT include deleted tool by default
      results =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true, include_deleted: false}
        )

      assert Enum.all?(results, fn result ->
               result.name in [platform_1.name, platform_3.name]
             end)

      # Should include deleted tool if include_deleted is true
      results_with_deleted =
        PlatformExternalTools.browse_platform_external_tools(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true, include_deleted: true}
        )

      assert Enum.all?(results_with_deleted, fn result ->
               result.name in [platform_1.name, platform_2.name, platform_3.name]
             end)
    end
  end

  describe "update_lti_external_tool_activity/2" do
    setup do
      institution = insert(:institution)

      {:ok, {pi, ar, _}} =
        Oli.Lti.PlatformExternalTools.register_lti_external_tool_activity(%{
          "name" => "Original Tool",
          "description" => "A test tool",
          "target_link_uri" => "https://example.com/launch",
          "client_id" => "abc-123",
          "login_url" => "https://example.com/login",
          "keyset_url" => "https://example.com/keyset",
          "redirect_uris" => "https://example.com/redirect",
          "institution_id" => institution.id
        })

      %{institution: institution, platform_instance: pi, activity_registration: ar}
    end

    test "successfully updates the tool", %{platform_instance: pi} do
      attrs = %{
        "name" => "Updated Tool Name",
        "description" => "Updated description"
      }

      assert {:ok, result} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity(pi.id, attrs)

      assert result.updated_platform_instance.name == "Updated Tool Name"
      assert result.updated_activity_registration.description == "Updated description"
    end

    test "fails when platform_instance is not found" do
      attrs = %{"name" => "Any", "description" => "Some"}

      assert {:error, :platform_instance, {:not_found}, %{}} ==
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity(-1, attrs)
    end

    test "fails updating platform_instance due to missing required field", %{
      platform_instance: pi
    } do
      attrs = %{
        "description" => "Only description, name is missing",
        "name" => nil
        # name is missing
      }

      assert {:error, :updated_platform_instance, changeset, _} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity(pi.id, attrs)

      assert changeset.errors[:name]
    end

    test "fails when activity_registration is not found", %{platform_instance: pi} do
      Repo.delete_all(from(d in Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment))

      attrs = %{
        "name" => "New name",
        "description" => "New description"
      }

      assert {:error, :activity_registration, {:not_found}, %{}} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity(pi.id, attrs)
    end

    test "fails updating activity_registration due to missing description", %{
      platform_instance: pi
    } do
      attrs = %{
        "name" => "Valid name"
        # description is missing
      }

      assert {:error, :updated_activity_registration, %Ecto.Changeset{} = changeset, _} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity(pi.id, attrs)

      assert changeset.errors[:description]
    end
  end

  describe "get_platform_instance/1" do
    test "returns a platform_instance when found" do
      pi = insert(:platform_instance)

      result = Oli.Lti.PlatformExternalTools.get_platform_instance(pi.id)

      assert result.id == pi.id
      assert result.client_id == pi.client_id
    end

    test "returns nil when no platform_instance is found" do
      refute Oli.Lti.PlatformExternalTools.get_platform_instance(-1)
    end
  end

  describe "get_section_resources_with_lti_activities/1" do
    setup do
      section = insert(:section)

      lti_deployment = insert(:lti_external_tool_activity_deployment)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      lti_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: lti_activity_resource.id,
          revision_id: lti_activity_revision.id
        )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      %{
        section: section,
        lti_activity_resource: lti_activity_resource,
        lti_section_resource: lti_section_resource,
        page_section_resource: page_section_resource
      }
    end

    test "returns empty map when section has no LTI activities" do
      empty_section = insert(:section)

      result = PlatformExternalTools.get_section_resources_with_lti_activities(empty_section)

      assert result == %{}
    end

    test "returns map of LTI activity IDs to section resources", %{
      section: section,
      lti_activity_resource: lti_activity_resource,
      page_section_resource: page_section_resource
    } do
      result = PlatformExternalTools.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
      assert Map.has_key?(result, lti_activity_resource.id)

      section_resources = result[lti_activity_resource.id]
      assert is_list(section_resources)
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "handles multiple pages referencing the same LTI activity", %{
      section: section,
      lti_activity_resource: lti_activity_resource
    } do
      another_page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      another_page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: another_page_revision.resource_id,
          revision_id: another_page_revision.id
        )

      result = PlatformExternalTools.get_section_resources_with_lti_activities(section)

      section_resources = result[lti_activity_resource.id]
      assert length(section_resources) == 2

      section_resource_ids = Enum.map(section_resources, & &1.id)
      assert Enum.member?(section_resource_ids, another_page_section_resource.id)
    end

    test "handles multiple LTI activities referenced by pages", %{
      section: section
    } do
      lti_deployment2 = insert(:lti_external_tool_activity_deployment)

      activity_registration2 =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment2
        )

      lti_activity_revision2 =
        insert(:revision,
          activity_type_id: activity_registration2.id
        )

      lti_activity_resource2 = lti_activity_revision2.resource

      insert(:section_resource,
        section: section,
        resource_id: lti_activity_resource2.id,
        revision_id: lti_activity_revision2.id
      )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource2.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      result = PlatformExternalTools.get_section_resources_with_lti_activities(section)

      assert map_size(result) == 2
      assert Map.has_key?(result, lti_activity_resource2.id)

      section_resources = result[lti_activity_resource2.id]
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "ignores pages that don't reference LTI activities", %{
      section: section
    } do
      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: []
        )

      insert(:section_resource,
        section: section,
        resource_id: page_revision.resource_id,
        revision_id: page_revision.id
      )

      result = PlatformExternalTools.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
    end
  end

  describe "get_sections_with_lti_activities_for_platform_instance_id/1" do
    test "returns only sections that include section resources referencing deployed LTI tools" do
      section = insert(:section)
      lti_deployment = insert(:lti_external_tool_activity_deployment)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      insert(:section_resource,
        section: section,
        resource_id: lti_activity_resource.id,
        revision_id: lti_activity_revision.id,
        activity_type_id: activity_registration.id
      )

      result =
        PlatformExternalTools.get_sections_with_lti_activities_for_platform_instance_id(
          lti_deployment.platform_instance_id
        )

      assert Enum.any?(result, fn s -> s.id == section.id end)
    end

    test "returns empty list when no LTI activity deployments exist for platform" do
      platform = insert(:platform_instance)

      assert PlatformExternalTools.get_sections_with_lti_activities_for_platform_instance_id(
               platform.id
             ) == []
    end

    test "returns empty list when LTI activity is not used in any section" do
      platform = insert(:platform_instance)
      reg = insert(:activity_registration)

      _deployment =
        insert(:lti_external_tool_activity_deployment,
          platform_instance: platform,
          activity_registration: reg
        )

      assert PlatformExternalTools.get_sections_with_lti_activities_for_platform_instance_id(
               platform.id
             ) == []
    end
  end

  describe "get_sections_grouped_by_platform_instance_ids/1" do
    test "returns sections grouped by platform_instance_id" do
      section = insert(:section)
      platform = insert(:platform_instance)
      lti_deployment = insert(:lti_external_tool_activity_deployment, platform_instance: platform)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      insert(:section_resource,
        section: section,
        resource_id: revision.resource_id,
        revision_id: revision.id,
        activity_type_id: activity_registration.id
      )

      result =
        PlatformExternalTools.get_sections_grouped_by_platform_instance_ids([platform.id])

      assert Map.has_key?(result, platform.id)
      assert Enum.any?(result[platform.id], fn s -> s.id == section.id end)
    end

    test "returns empty map when no deployments match" do
      platform = insert(:platform_instance)

      result =
        PlatformExternalTools.get_sections_grouped_by_platform_instance_ids([platform.id])

      assert result == %{}
    end

    test "excludes platforms with no linked sections" do
      platform = insert(:platform_instance)

      activity_registration = insert(:activity_registration)

      _deployment =
        insert(:lti_external_tool_activity_deployment,
          platform_instance: platform,
          activity_registration: activity_registration
        )

      result =
        PlatformExternalTools.get_sections_grouped_by_platform_instance_ids([platform.id])

      assert result == %{}
    end
  end

  describe "update_lti_external_tool_activity_deployment/2" do
    setup do
      deployment = insert(:lti_external_tool_activity_deployment)
      %{deployment: deployment}
    end

    test "successfully updates the deployment", %{deployment: deployment} do
      updated_attrs = %{
        status: :disabled
      }

      assert {:ok, updated} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity_deployment(
                 deployment,
                 updated_attrs
               )

      assert updated.status == updated_attrs.status
    end

    test "returns error changeset when given invalid attrs", %{deployment: deployment} do
      invalid_attrs = %{status: :invalid_status}

      assert {:error, changeset} =
               Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity_deployment(
                 deployment,
                 invalid_attrs
               )

      refute changeset.valid?
    end
  end

  describe "get_platform_instance_with_deployment/1" do
    test "returns the platform_instance and associated deployment when found" do
      deployment =
        insert(:lti_external_tool_activity_deployment)

      assert {returned_pi, returned_deployment} =
               Oli.Lti.PlatformExternalTools.get_platform_instance_with_deployment(
                 deployment.platform_instance_id
               )

      assert returned_pi.id == deployment.platform_instance_id
      assert returned_deployment.deployment_id == deployment.deployment_id
    end

    test "returns nil when the platform_instance does not exist" do
      refute Oli.Lti.PlatformExternalTools.get_platform_instance_with_deployment(-1)
    end

    test "returns nil when there is no associated deployment" do
      platform_instance = insert(:platform_instance)

      refute Oli.Lti.PlatformExternalTools.get_platform_instance_with_deployment(
               platform_instance.id
             )
    end
  end

  defp create_section_resource(_) do
    section = insert(:section)
    resource = insert(:resource)

    %{
      section: section,
      resource: resource,
      valid_attrs: %{
        type: :ltiResourceLink,
        url: "https://example.com/resource",
        title: "Test Resource",
        text: "Test resource description",
        custom: %{"param1" => "value1"},
        section_id: section.id,
        resource_id: resource.id
      }
    }
  end

  describe "create_section_resource_deep_link/1" do
    setup [:create_section_resource]

    test "creates a deep link with valid attributes", %{valid_attrs: valid_attrs} do
      assert {:ok, deep_link} =
               PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      assert deep_link.type == :ltiResourceLink
      assert deep_link.url == "https://example.com/resource"
      assert deep_link.title == "Test Resource"
      assert deep_link.text == "Test resource description"
      assert deep_link.custom == %{"param1" => "value1"}
      assert deep_link.section_id == valid_attrs.section_id
      assert deep_link.resource_id == valid_attrs.resource_id
    end

    test "creates a deep link with minimal required attributes", %{
      section: section,
      resource: resource
    } do
      minimal_attrs = %{
        type: :ltiLink,
        section_id: section.id,
        resource_id: resource.id
      }

      assert {:ok, deep_link} =
               PlatformExternalTools.create_section_resource_deep_link(minimal_attrs)

      assert deep_link.type == :ltiLink
      assert deep_link.section_id == section.id
      assert deep_link.resource_id == resource.id
      assert deep_link.url == nil
      assert deep_link.title == nil
      assert deep_link.text == nil
      assert deep_link.custom == %{}
    end

    test "fails when required attributes are missing" do
      invalid_attrs = %{
        url: "https://example.com/resource",
        title: "Test Resource"
        # missing type, section_id, resource_id
      }

      assert {:error, changeset} =
               PlatformExternalTools.create_section_resource_deep_link(invalid_attrs)

      refute changeset.valid?
      # type has a default value, so only section_id and resource_id should have errors
      assert changeset.errors[:section_id]
      assert changeset.errors[:resource_id]
    end

    test "fails with invalid type" do
      invalid_attrs = %{
        type: :invalidType,
        section_id: 1,
        resource_id: 1
      }

      assert {:error, changeset} =
               PlatformExternalTools.create_section_resource_deep_link(invalid_attrs)

      refute changeset.valid?
      assert changeset.errors[:type]
    end
  end

  describe "upsert_section_resource_deep_link/1" do
    setup [:create_section_resource]

    test "creates a new deep link when none exists", %{valid_attrs: valid_attrs} do
      assert {:ok, deep_link} =
               PlatformExternalTools.upsert_section_resource_deep_link(valid_attrs)

      assert deep_link.type == :ltiResourceLink
      assert deep_link.url == "https://example.com/resource"
      assert deep_link.title == "Test Resource"
    end

    test "updates existing deep link when one exists", %{valid_attrs: valid_attrs} do
      # Create initial deep link
      {:ok, initial_deep_link} =
        PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      # Upsert with updated attributes
      updated_attrs =
        Map.merge(valid_attrs, %{
          url: "https://updated.com/resource",
          title: "Updated Resource",
          custom: %{"updated" => "value"}
        })

      assert {:ok, updated_deep_link} =
               PlatformExternalTools.upsert_section_resource_deep_link(updated_attrs)

      # Should have same ID (updated, not created new)
      assert updated_deep_link.id == initial_deep_link.id
      assert updated_deep_link.url == "https://updated.com/resource"
      assert updated_deep_link.title == "Updated Resource"
      assert updated_deep_link.custom == %{"updated" => "value"}

      # Verify only one record exists
      count =
        Repo.aggregate(Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink, :count, :id)

      assert count == 1
    end

    test "handles conflict on section_id and resource_id combination", %{
      section: section,
      resource: resource
    } do
      attrs1 = %{
        type: :ltiResourceLink,
        url: "https://first.com",
        title: "First",
        section_id: section.id,
        resource_id: resource.id
      }

      attrs2 = %{
        type: :ltiResourceLink,
        url: "https://second.com",
        title: "Second",
        section_id: section.id,
        resource_id: resource.id
      }

      # Create first record
      {:ok, first_deep_link} =
        PlatformExternalTools.upsert_section_resource_deep_link(attrs1)

      # Upsert second record with same section_id and resource_id
      {:ok, second_deep_link} =
        PlatformExternalTools.upsert_section_resource_deep_link(attrs2)

      # Should be same record ID (updated)
      assert first_deep_link.id == second_deep_link.id
      assert second_deep_link.type == :ltiResourceLink
      assert second_deep_link.url == "https://second.com"
      assert second_deep_link.title == "Second"
    end
  end

  describe "get_section_resource_deep_link_by/1" do
    setup [:create_section_resource]

    test "returns deep link when found", %{valid_attrs: valid_attrs} do
      {:ok, created_deep_link} =
        PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      result =
        PlatformExternalTools.get_section_resource_deep_link_by(
          section_id: valid_attrs.section_id,
          resource_id: valid_attrs.resource_id
        )

      assert result.id == created_deep_link.id
      assert result.type == :ltiResourceLink
      assert result.url == "https://example.com/resource"
    end

    test "returns nil when not found" do
      result =
        PlatformExternalTools.get_section_resource_deep_link_by(
          section_id: 999,
          resource_id: 999
        )

      assert result == nil
    end

    test "can search by different attributes", %{valid_attrs: valid_attrs} do
      {:ok, created_deep_link} =
        PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      # Search by ID
      result =
        PlatformExternalTools.get_section_resource_deep_link_by(id: created_deep_link.id)

      assert result.id == created_deep_link.id

      # Search by type
      result =
        PlatformExternalTools.get_section_resource_deep_link_by(type: :ltiResourceLink)

      assert result.id == created_deep_link.id

      # Search by URL
      result =
        PlatformExternalTools.get_section_resource_deep_link_by(
          url: "https://example.com/resource"
        )

      assert result.id == created_deep_link.id
    end
  end

  describe "update_section_resource_deep_link/2" do
    setup [:create_section_resource]

    test "successfully updates deep link", %{valid_attrs: valid_attrs} do
      {:ok, deep_link} = PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      update_attrs = %{
        type: :ltiAssignmentAndGradeServices,
        url: "https://updated.com/resource",
        title: "Updated Title",
        text: "Updated description",
        custom: %{"new_param" => "new_value"}
      }

      assert {:ok, updated_deep_link} =
               PlatformExternalTools.update_section_resource_deep_link(deep_link, update_attrs)

      assert updated_deep_link.id == deep_link.id
      assert updated_deep_link.type == :ltiAssignmentAndGradeServices
      assert updated_deep_link.url == "https://updated.com/resource"
      assert updated_deep_link.title == "Updated Title"
      assert updated_deep_link.text == "Updated description"
      assert updated_deep_link.custom == %{"new_param" => "new_value"}
    end

    test "returns error changeset for invalid updates", %{valid_attrs: valid_attrs} do
      {:ok, deep_link} = PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      invalid_attrs = %{
        type: :invalidType
      }

      assert {:error, changeset} =
               PlatformExternalTools.update_section_resource_deep_link(deep_link, invalid_attrs)

      refute changeset.valid?
      assert changeset.errors[:type]
    end

    test "can partially update fields", %{valid_attrs: valid_attrs} do
      {:ok, deep_link} = PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      update_attrs = %{
        title: "Only Title Updated"
      }

      assert {:ok, updated_deep_link} =
               PlatformExternalTools.update_section_resource_deep_link(deep_link, update_attrs)

      # Only title should be updated
      assert updated_deep_link.title == "Only Title Updated"
      # Other fields should remain the same
      assert updated_deep_link.type == deep_link.type
      assert updated_deep_link.url == deep_link.url
      assert updated_deep_link.text == deep_link.text
      assert updated_deep_link.custom == deep_link.custom
    end
  end

  describe "delete_section_resource_deep_link/1" do
    setup [:create_section_resource]

    test "successfully deletes deep link", %{valid_attrs: valid_attrs} do
      {:ok, deep_link} = PlatformExternalTools.create_section_resource_deep_link(valid_attrs)

      assert {:ok, deleted_deep_link} =
               PlatformExternalTools.delete_section_resource_deep_link(deep_link)

      assert deleted_deep_link.id == deep_link.id

      # Verify it's actually deleted
      result = PlatformExternalTools.get_section_resource_deep_link_by(id: deep_link.id)
      assert result == nil
    end

    test "returns error when trying to delete non-existent record", %{
      section: section,
      resource: resource
    } do
      # Create and delete a deep link first
      {:ok, deep_link} =
        PlatformExternalTools.create_section_resource_deep_link(%{
          type: :ltiResourceLink,
          section_id: section.id,
          resource_id: resource.id
        })

      {:ok, _} = PlatformExternalTools.delete_section_resource_deep_link(deep_link)

      # Try to delete the same record again - this should raise a stale entry error
      assert_raise Ecto.StaleEntryError, fn ->
        PlatformExternalTools.delete_section_resource_deep_link(deep_link)
      end
    end
  end

  describe "integration scenarios" do
    setup [:create_section_resource]

    test "complete lifecycle: create, read, update, delete", %{
      section: section,
      resource: resource
    } do
      # Create
      attrs = %{
        type: :ltiResourceLink,
        url: "https://example.com",
        title: "Original Title",
        section_id: section.id,
        resource_id: resource.id
      }

      {:ok, deep_link} = PlatformExternalTools.create_section_resource_deep_link(attrs)
      assert deep_link.title == "Original Title"

      # Read
      found = PlatformExternalTools.get_section_resource_deep_link_by(id: deep_link.id)
      assert found.id == deep_link.id

      # Update
      {:ok, updated} =
        PlatformExternalTools.update_section_resource_deep_link(deep_link, %{
          title: "Updated Title"
        })

      assert updated.title == "Updated Title"

      # Delete
      {:ok, _} = PlatformExternalTools.delete_section_resource_deep_link(updated)

      # Verify deletion
      refute PlatformExternalTools.get_section_resource_deep_link_by(id: deep_link.id)
    end

    test "upsert behavior maintains referential integrity", %{
      section: section,
      resource: resource
    } do
      attrs = %{
        type: :ltiResourceLink,
        url: "https://example.com",
        section_id: section.id,
        resource_id: resource.id
      }

      # First upsert creates
      {:ok, first} = PlatformExternalTools.upsert_section_resource_deep_link(attrs)

      # Second upsert updates
      updated_attrs = Map.put(attrs, :title, "Updated")
      {:ok, second} = PlatformExternalTools.upsert_section_resource_deep_link(updated_attrs)

      # Should be same record
      assert first.id == second.id
      assert second.title == "Updated"

      # Should only have one record total
      count =
        Repo.aggregate(Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink, :count, :id)

      assert count == 1
    end
  end
end
