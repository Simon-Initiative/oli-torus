defmodule Oli.Lti.PlatformInstancesTest do
  use Oli.DataCase

  alias Oli.Lti.PlatformInstances
  alias Oli.Lti.PlatformInstances.BrowseOptions
  alias Oli.Repo.{Paging, Sorting}

  describe "lti_1p3_platform_instances" do
    alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance

    @valid_attrs %{
      client_id: "some client_id",
      custom_params: "some custom_params",
      description: "some description",
      keyset_url: "some keyset_url",
      login_url: "some login_url",
      name: "some name",
      redirect_uris: "some redirect_uris",
      target_link_uri: "some target_link_uri"
    }
    @update_attrs %{
      client_id: "some updated client_id",
      custom_params: "some updated custom_params",
      description: "some updated description",
      keyset_url: "some updated keyset_url",
      login_url: "some updated login_url",
      name: "some updated name",
      redirect_uris: "some updated redirect_uris",
      target_link_uri: "some updated target_link_uri"
    }
    @invalid_attrs %{
      client_id: nil,
      custom_params: nil,
      description: nil,
      keyset_url: nil,
      login_url: nil,
      name: nil,
      redirect_uris: nil,
      target_link_uri: nil
    }

    def platform_instance_fixture(attrs \\ %{}) do
      {:ok, platform_instance} =
        attrs
        |> Enum.into(@valid_attrs)
        |> PlatformInstances.create_platform_instance()

      platform_instance
    end

    test "list_lti_1p3_platform_instances/0 returns all lti_1p3_platform_instances" do
      platform_instance = platform_instance_fixture()
      assert PlatformInstances.list_lti_1p3_platform_instances() == [platform_instance]
    end

    test "get_platform_instance!/1 returns the platform_instance with given id" do
      platform_instance = platform_instance_fixture()
      assert PlatformInstances.get_platform_instance!(platform_instance.id) == platform_instance
    end

    test "create_platform_instance/1 with valid data creates a platform_instance" do
      assert {:ok, %PlatformInstance{} = platform_instance} =
               PlatformInstances.create_platform_instance(@valid_attrs)

      assert platform_instance.client_id == "some client_id"
      assert platform_instance.custom_params == "some custom_params"
      assert platform_instance.description == "some description"
      assert platform_instance.keyset_url == "some keyset_url"
      assert platform_instance.login_url == "some login_url"
      assert platform_instance.name == "some name"
      assert platform_instance.redirect_uris == "some redirect_uris"
      assert platform_instance.target_link_uri == "some target_link_uri"
    end

    test "create_platform_instance/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               PlatformInstances.create_platform_instance(@invalid_attrs)
    end

    test "update_platform_instance/2 with valid data updates the platform_instance" do
      platform_instance = platform_instance_fixture()

      assert {:ok, %PlatformInstance{} = platform_instance} =
               PlatformInstances.update_platform_instance(platform_instance, @update_attrs)

      assert platform_instance.client_id == "some updated client_id"
      assert platform_instance.custom_params == "some updated custom_params"
      assert platform_instance.description == "some updated description"
      assert platform_instance.keyset_url == "some updated keyset_url"
      assert platform_instance.login_url == "some updated login_url"
      assert platform_instance.name == "some updated name"
      assert platform_instance.redirect_uris == "some updated redirect_uris"
      assert platform_instance.target_link_uri == "some updated target_link_uri"
    end

    test "update_platform_instance/2 with invalid data returns error changeset" do
      platform_instance = platform_instance_fixture()

      assert {:error, %Ecto.Changeset{}} =
               PlatformInstances.update_platform_instance(platform_instance, @invalid_attrs)

      assert platform_instance == PlatformInstances.get_platform_instance!(platform_instance.id)
    end

    test "delete_platform_instance/1 deletes the platform_instance" do
      platform_instance = platform_instance_fixture()

      assert {:ok, %PlatformInstance{}} =
               PlatformInstances.delete_platform_instance(platform_instance)

      assert_raise Ecto.NoResultsError, fn ->
        PlatformInstances.get_platform_instance!(platform_instance.id)
      end
    end

    test "change_platform_instance/1 returns a platform_instance changeset" do
      platform_instance = platform_instance_fixture()
      assert %Ecto.Changeset{} = PlatformInstances.change_platform_instance(platform_instance)
    end
  end

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
        PlatformInstances.browse_platform_instances(
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
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert length(results) == 3
      assert Enum.map(results, & &1.name) == [platform_1.name, platform_2.name, platform_3.name]
    end

    test "browse with text search filters by name", %{platform_2: platform_2} do
      results =
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{text_search: "BBB", include_disabled: true}
        )

      assert length(results) == 1
      assert hd(results).name == platform_2.name
    end

    test "browse with text search filters by description", %{platform_3: platform_3} do
      results =
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{text_search: "Third", include_disabled: true}
        )

      assert length(results) == 1
      assert hd(results).description == platform_3.description
    end

    test "browse respects pagination", %{platform_1: platform_1, platform_2: platform_2} do
      results =
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 2},
          %Sorting{field: :name, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert length(results) == 2
      assert Enum.map(results, & &1.name) == [platform_1.name, platform_2.name]

      results =
        PlatformInstances.browse_platform_instances(
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
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :name, direction: :desc},
          %BrowseOptions{include_disabled: true}
        )

      assert Enum.map(results, & &1.name) == [platform_3.name, platform_2.name, platform_1.name]

      # Test sorting by description asc
      results =
        PlatformInstances.browse_platform_instances(
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
        PlatformInstances.browse_platform_instances(
          %Paging{offset: 0, limit: 10},
          %Sorting{field: :status, direction: :asc},
          %BrowseOptions{include_disabled: true}
        )

      assert Enum.map(results, & &1.status) == [:disabled, :enabled, :enabled]
    end
  end
end
