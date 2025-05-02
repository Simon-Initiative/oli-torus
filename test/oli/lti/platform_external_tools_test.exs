defmodule Oli.Lti.PlatformExternalToolsTest do
  use Oli.DataCase

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
end
