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

    test "partial unique index on client_id allows multiple deleted instances with same client_id" do
      # Create first platform instance with active status
      active_instance =
        platform_instance_fixture(%{client_id: "same_client_id", status: :active})

      # Create second platform instance with deleted status and same client_id - should succeed
      deleted_instance =
        platform_instance_fixture(%{client_id: "same_client_id", status: :deleted})

      # Verify both instances exist
      assert active_instance.id != deleted_instance.id
      assert active_instance.client_id == deleted_instance.client_id
      assert active_instance.status == :active
      assert deleted_instance.status == :deleted

      # Try to create another active instance with same client_id - should fail due to unique constraint
      assert_raise Ecto.ConstraintError, fn ->
        platform_instance_fixture(%{client_id: "same_client_id", status: :active})
      end
    end

    test "partial unique index on client_id prevents multiple active instances with same client_id" do
      # Create first platform instance with active status
      platform_instance_fixture(%{client_id: "unique_client_id", status: :active})

      # Try to create second platform instance with active status and same client_id - should fail
      assert_raise Ecto.ConstraintError, fn ->
        platform_instance_fixture(%{client_id: "unique_client_id", status: :active})
      end
    end

    test "can create, delete, and re-enable LTI platform instance" do
      # Create a new LTI platform instance
      platform_instance =
        platform_instance_fixture(%{
          client_id: "test_client_id",
          name: "Test Platform",
          status: :active
        })

      # Verify it was created successfully
      assert platform_instance.status == :active
      assert platform_instance.client_id == "test_client_id"
      assert platform_instance.name == "Test Platform"

      # Delete the platform instance (set status to deleted)
      assert {:ok, deleted_instance} =
               PlatformInstances.update_platform_instance(
                 platform_instance,
                 %{status: :deleted}
               )

      assert deleted_instance.status == :deleted

      # Verify the deleted instance still exists but is marked as deleted
      retrieved_instance = PlatformInstances.get_platform_instance!(deleted_instance.id)
      assert retrieved_instance.status == :deleted
      assert retrieved_instance.client_id == "test_client_id"

      # Re-enable the platform instance (set status back to active)
      assert {:ok, reenabled_instance} =
               PlatformInstances.update_platform_instance(
                 deleted_instance,
                 %{status: :active}
               )

      assert reenabled_instance.status == :active
      assert reenabled_instance.client_id == "test_client_id"
      assert reenabled_instance.name == "Test Platform"

      # Verify the re-enabled instance is properly active
      final_instance = PlatformInstances.get_platform_instance!(reenabled_instance.id)
      assert final_instance.status == :active
      assert final_instance.id == platform_instance.id
    end
  end
end
