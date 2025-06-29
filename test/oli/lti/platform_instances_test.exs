defmodule Oli.Lti.PlatformInstancesTest do
  use Oli.DataCase

  alias Oli.Lti.PlatformInstances
  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance

  describe "lti_1p3_platform_instances" do
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

      result = PlatformInstances.list_lti_1p3_platform_instances() |> hd()

      assert result.client_id == platform_instance.client_id
      assert result.custom_params == platform_instance.custom_params
      assert result.description == platform_instance.description
      assert result.keyset_url == platform_instance.keyset_url
      assert result.login_url == platform_instance.login_url
      assert result.name == platform_instance.name
      assert result.redirect_uris == platform_instance.redirect_uris
      assert result.target_link_uri == platform_instance.target_link_uri
    end

    test "get_platform_instance!/1 returns the platform_instance with given id" do
      platform_instance = platform_instance_fixture()

      result = PlatformInstances.get_platform_instance!(platform_instance.id)

      assert result.client_id == platform_instance.client_id
      assert result.custom_params == platform_instance.custom_params
      assert result.description == platform_instance.description
      assert result.keyset_url == platform_instance.keyset_url
      assert result.login_url == platform_instance.login_url
      assert result.name == platform_instance.name
      assert result.redirect_uris == platform_instance.redirect_uris
      assert result.target_link_uri == platform_instance.target_link_uri
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

      result = PlatformInstances.get_platform_instance!(platform_instance.id)

      assert result.client_id == platform_instance.client_id
      assert result.custom_params == platform_instance.custom_params
      assert result.description == platform_instance.description
      assert result.keyset_url == platform_instance.keyset_url
      assert result.login_url == platform_instance.login_url
      assert result.name == platform_instance.name
      assert result.redirect_uris == platform_instance.redirect_uris
      assert result.target_link_uri == platform_instance.target_link_uri
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
end
