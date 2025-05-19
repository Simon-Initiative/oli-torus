defmodule Oli.Lti.PlatformExternalToolsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.BrowseOptions
  alias Oli.Repo.{Paging, Sorting}

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
end
