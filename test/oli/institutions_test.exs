defmodule Oli.InstitutionsTest do
  use Oli.DataCase

  alias Oli.Institutions

  describe "registrations" do
    alias Oli.Institutions.Registration

    @valid_attrs %{auth_login_url: "some auth_login_url", auth_server: "some auth_server", auth_token_url: "some auth_token_url", client_id: "some client_id", issuer: "some issuer", key_set_url: "some key_set_url", kid: "some kid"}
    @update_attrs %{auth_login_url: "some updated auth_login_url", auth_server: "some updated auth_server", auth_token_url: "some updated auth_token_url", client_id: "some updated client_id", issuer: "some updated issuer", key_set_url: "some updated key_set_url", kid: "some updated kid"}
    @invalid_attrs %{auth_login_url: nil, auth_server: nil, auth_token_url: nil, client_id: nil, issuer: nil, key_set_url: nil, kid: nil}

    def registration_fixture(attrs \\ %{}) do
      {:ok, registration} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Institutions.create_registration()

      registration
    end

    test "list_registrations/0 returns all registrations" do
      registration = registration_fixture()
      assert Institutions.list_registrations() == [registration]
    end

    test "get_registration!/1 returns the registration with given id" do
      registration = registration_fixture()
      assert Institutions.get_registration!(registration.id) == registration
    end

    test "create_registration/1 with valid data creates a registration" do
      assert {:ok, %Registration{} = registration} = Institutions.create_registration(@valid_attrs)
      assert registration.auth_login_url == "some auth_login_url"
      assert registration.auth_server == "some auth_server"
      assert registration.auth_token_url == "some auth_token_url"
      assert registration.client_id == "some client_id"
      assert registration.issuer == "some issuer"
      assert registration.key_set_url == "some key_set_url"
      assert registration.kid == "some kid"
    end

    test "create_registration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Institutions.create_registration(@invalid_attrs)
    end

    test "update_registration/2 with valid data updates the registration" do
      registration = registration_fixture()
      assert {:ok, %Registration{} = registration} = Institutions.update_registration(registration, @update_attrs)
      assert registration.auth_login_url == "some updated auth_login_url"
      assert registration.auth_server == "some updated auth_server"
      assert registration.auth_token_url == "some updated auth_token_url"
      assert registration.client_id == "some updated client_id"
      assert registration.issuer == "some updated issuer"
      assert registration.key_set_url == "some updated key_set_url"
      assert registration.kid == "some updated kid"
    end

    test "update_registration/2 with invalid data returns error changeset" do
      registration = registration_fixture()
      assert {:error, %Ecto.Changeset{}} = Institutions.update_registration(registration, @invalid_attrs)
      assert registration == Institutions.get_registration!(registration.id)
    end

    test "delete_registration/1 deletes the registration" do
      registration = registration_fixture()
      assert {:ok, %Registration{}} = Institutions.delete_registration(registration)
      assert_raise Ecto.NoResultsError, fn -> Institutions.get_registration!(registration.id) end
    end

    test "change_registration/1 returns a registration changeset" do
      registration = registration_fixture()
      assert %Ecto.Changeset{} = Institutions.change_registration(registration)
    end
  end

  describe "deployments" do
    alias Oli.Institutions.Deployment

    @valid_attrs %{deployment_id: "some deployment_id"}
    @update_attrs %{deployment_id: "some updated deployment_id"}
    @invalid_attrs %{deployment_id: nil}

    def deployment_fixture(attrs \\ %{}) do
      {:ok, deployment} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Institutions.create_deployment()

      deployment
    end

    test "list_deployments/0 returns all deployments" do
      deployment = deployment_fixture()
      assert Institutions.list_deployments() == [deployment]
    end

    test "get_deployment!/1 returns the deployment with given id" do
      deployment = deployment_fixture()
      assert Institutions.get_deployment!(deployment.id) == deployment
    end

    test "create_deployment/1 with valid data creates a deployment" do
      assert {:ok, %Deployment{} = deployment} = Institutions.create_deployment(@valid_attrs)
      assert deployment.deployment_id == "some deployment_id"
    end

    test "create_deployment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Institutions.create_deployment(@invalid_attrs)
    end

    test "update_deployment/2 with valid data updates the deployment" do
      deployment = deployment_fixture()
      assert {:ok, %Deployment{} = deployment} = Institutions.update_deployment(deployment, @update_attrs)
      assert deployment.deployment_id == "some updated deployment_id"
    end

    test "update_deployment/2 with invalid data returns error changeset" do
      deployment = deployment_fixture()
      assert {:error, %Ecto.Changeset{}} = Institutions.update_deployment(deployment, @invalid_attrs)
      assert deployment == Institutions.get_deployment!(deployment.id)
    end

    test "delete_deployment/1 deletes the deployment" do
      deployment = deployment_fixture()
      assert {:ok, %Deployment{}} = Institutions.delete_deployment(deployment)
      assert_raise Ecto.NoResultsError, fn -> Institutions.get_deployment!(deployment.id) end
    end

    test "change_deployment/1 returns a deployment changeset" do
      deployment = deployment_fixture()
      assert %Ecto.Changeset{} = Institutions.change_deployment(deployment)
    end
  end
end
