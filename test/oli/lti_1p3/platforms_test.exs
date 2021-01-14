defmodule Oli.Lti_1p3.PlatformsTest do
  use Oli.DataCase

  alias Oli.Lti_1p3.Platforms

  describe "lti_1p3_platforms" do
    alias Oli.Lti_1p3.Platform

    @valid_attrs %{client_id: "some client_id", custom_params: "some custom_params", description: "some description", keyset_url: "some keyset_url", login_url: "some login_url", name: "some name", redirect_uris: "some redirect_uris", target_link_uri: "some target_link_uri"}
    @update_attrs %{client_id: "some updated client_id", custom_params: "some updated custom_params", description: "some updated description", keyset_url: "some updated keyset_url", login_url: "some updated login_url", name: "some updated name", redirect_uris: "some updated redirect_uris", target_link_uri: "some updated target_link_uri"}
    @invalid_attrs %{client_id: nil, custom_params: nil, description: nil, keyset_url: nil, login_url: nil, name: nil, redirect_uris: nil, target_link_uri: nil}

    def platform_fixture(attrs \\ %{}) do
      {:ok, platform} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Platforms.create_platform()

      platform
    end

    test "list_lti_1p3_platforms/0 returns all lti_1p3_platforms" do
      platform = platform_fixture()
      assert Platforms.list_lti_1p3_platforms() == [platform]
    end

    test "get_platform!/1 returns the platform with given id" do
      platform = platform_fixture()
      assert Platforms.get_platform!(platform.id) == platform
    end

    test "create_platform/1 with valid data creates a platform" do
      assert {:ok, %Platform{} = platform} = Platforms.create_platform(@valid_attrs)
      assert platform.client_id == "some client_id"
      assert platform.custom_params == "some custom_params"
      assert platform.description == "some description"
      assert platform.keyset_url == "some keyset_url"
      assert platform.login_url == "some login_url"
      assert platform.name == "some name"
      assert platform.redirect_uris == "some redirect_uris"
      assert platform.target_link_uri == "some target_link_uri"
    end

    test "create_platform/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Platforms.create_platform(@invalid_attrs)
    end

    test "update_platform/2 with valid data updates the platform" do
      platform = platform_fixture()
      assert {:ok, %Platform{} = platform} = Platforms.update_platform(platform, @update_attrs)
      assert platform.client_id == "some updated client_id"
      assert platform.custom_params == "some updated custom_params"
      assert platform.description == "some updated description"
      assert platform.keyset_url == "some updated keyset_url"
      assert platform.login_url == "some updated login_url"
      assert platform.name == "some updated name"
      assert platform.redirect_uris == "some updated redirect_uris"
      assert platform.target_link_uri == "some updated target_link_uri"
    end

    test "update_platform/2 with invalid data returns error changeset" do
      platform = platform_fixture()
      assert {:error, %Ecto.Changeset{}} = Platforms.update_platform(platform, @invalid_attrs)
      assert platform == Platforms.get_platform!(platform.id)
    end

    test "delete_platform/1 deletes the platform" do
      platform = platform_fixture()
      assert {:ok, %Platform{}} = Platforms.delete_platform(platform)
      assert_raise Ecto.NoResultsError, fn -> Platforms.get_platform!(platform.id) end
    end

    test "change_platform/1 returns a platform changeset" do
      platform = platform_fixture()
      assert %Ecto.Changeset{} = Platforms.change_platform(platform)
    end
  end
end
