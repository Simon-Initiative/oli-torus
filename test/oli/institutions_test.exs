defmodule Oli.InstitutionsTest do
  use Oli.DataCase

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Institutions.PendingRegistration
  alias Oli.Lti_1p3.Tool.Registration

  describe "registrations" do
    setup do
      institution = institution_fixture()
      jwk = jwk_fixture()
      registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})

      # registration = registration |> Repo.preload([:deployments])

      %{institution: institution, jwk: jwk, registration: registration}
    end

    @valid_attrs %{
      auth_login_url: "some auth_login_url",
      auth_server: "some auth_server",
      auth_token_url: "some auth_token_url",
      client_id: "some client_id",
      issuer: "some issuer",
      key_set_url: "some key_set_url"
    }
    @update_attrs %{
      auth_login_url: "some updated auth_login_url",
      auth_server: "some updated auth_server",
      auth_token_url: "some updated auth_token_url",
      client_id: "some updated client_id",
      issuer: "some updated issuer",
      key_set_url: "some updated key_set_url"
    }
    @invalid_attrs %{
      auth_login_url: nil,
      auth_server: nil,
      auth_token_url: nil,
      client_id: nil,
      issuer: nil,
      key_set_url: nil
    }

    test "list_registrations/0 returns all registrations", %{registration: registration} do
      assert Institutions.list_registrations() |> Enum.map(& &1.id) == [registration.id]
    end

    test "get_registration!/1 returns the registration with given id", %{
      registration: registration
    } do
      assert Institutions.get_registration!(registration.id) == registration
    end

    test "create_registration/1 with valid data creates a registration", %{
      institution: institution,
      jwk: jwk
    } do
      assert {:ok, %Registration{} = registration} =
               Institutions.create_registration(
                 Enum.into(
                   %{
                     institution_id: institution.id,
                     tool_jwk_id: jwk.id,
                     issuer: "some other issuer"
                   },
                   @valid_attrs
                 )
               )

      assert registration.auth_login_url == "some auth_login_url"
      assert registration.auth_server == "some auth_server"
      assert registration.auth_token_url == "some auth_token_url"
      assert registration.client_id == "some client_id"
      assert registration.issuer == "some other issuer"
      assert registration.key_set_url == "some key_set_url"
    end

    test "create_registration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Institutions.create_registration(@invalid_attrs)
    end

    test "update_registration/2 with valid data updates the registration", %{
      registration: registration
    } do
      assert {:ok, %Registration{} = registration} =
               Institutions.update_registration(registration, @update_attrs)

      assert registration.auth_login_url == "some updated auth_login_url"
      assert registration.auth_server == "some updated auth_server"
      assert registration.auth_token_url == "some updated auth_token_url"
      assert registration.client_id == "some updated client_id"
      assert registration.issuer == "some updated issuer"
      assert registration.key_set_url == "some updated key_set_url"
    end

    test "update_registration/2 with invalid data returns error changeset", %{
      registration: registration
    } do
      assert {:error, %Ecto.Changeset{}} =
               Institutions.update_registration(registration, @invalid_attrs)

      assert registration == Institutions.get_registration!(registration.id)
    end

    test "delete_registration/1 deletes the registration", %{registration: registration} do
      assert {:ok, %Registration{}} = Institutions.delete_registration(registration)
      assert_raise Ecto.NoResultsError, fn -> Institutions.get_registration!(registration.id) end
    end

    test "change_registration/1 returns a registration changeset", %{registration: registration} do
      assert %Ecto.Changeset{} = Institutions.change_registration(registration)
    end
  end

  describe "deployments" do
    alias Lti_1p3.DataProviders.EctoProvider.Deployment

    setup do
      institution = institution_fixture()
      jwk = jwk_fixture()
      registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
      deployment = deployment_fixture(%{registration_id: registration.id})

      registration = registration |> Repo.preload([:deployments])

      %{institution: institution, jwk: jwk, registration: registration, deployment: deployment}
    end

    @valid_attrs %{deployment_id: "some deployment_id"}
    @update_attrs %{deployment_id: "some updated deployment_id"}
    @invalid_attrs %{deployment_id: nil, registration_id: nil}

    test "list_deployments/0 returns all deployments", %{deployment: deployment} do
      assert Institutions.list_deployments() == [deployment]
    end

    test "get_deployment!/1 returns the deployment with given id", %{deployment: deployment} do
      assert Institutions.get_deployment!(deployment.id) == deployment
    end

    test "create_deployment/1 with valid data creates a deployment", %{registration: registration} do
      assert {:ok, %Deployment{} = deployment} =
               Institutions.create_deployment(
                 @valid_attrs
                 |> Enum.into(%{registration_id: registration.id})
               )

      assert deployment.deployment_id == "some deployment_id"
    end

    test "create_deployment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Institutions.create_deployment(@invalid_attrs)
    end

    test "update_deployment/2 with valid data updates the deployment", %{deployment: deployment} do
      assert {:ok, %Deployment{} = deployment} =
               Institutions.update_deployment(deployment, @update_attrs)

      assert deployment.deployment_id == "some updated deployment_id"
    end

    test "update_deployment/2 with invalid data returns error changeset", %{
      deployment: deployment
    } do
      assert {:error, %Ecto.Changeset{}} =
               Institutions.update_deployment(deployment, @invalid_attrs)

      assert deployment == Institutions.get_deployment!(deployment.id)
    end

    test "delete_deployment/1 deletes the deployment", %{deployment: deployment} do
      assert {:ok, %Deployment{}} = Institutions.delete_deployment(deployment)
      assert_raise Ecto.NoResultsError, fn -> Institutions.get_deployment!(deployment.id) end
    end

    test "change_deployment/1 returns a deployment changeset", %{deployment: deployment} do
      assert %Ecto.Changeset{} = Institutions.change_deployment(deployment)
    end
  end

  describe "pending_registration" do
    alias Lti_1p3.Tool.Deployment

    setup do
      institution = institution_fixture()
      jwk = jwk_fixture()
      registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
      deployment = deployment_fixture(%{registration_id: registration.id})
      pending_registration = pending_registration_fixture()

      registration = registration |> Repo.preload([:deployments])

      %{
        institution: institution,
        jwk: jwk,
        registration: registration,
        deployment: deployment,
        pending_registration: pending_registration
      }
    end

    @valid_attrs %{
      name: "some institution",
      country_code: "some country_code",
      institution_email: "some institution_email",
      institution_url: "some institution_url",
      timezone: "some timezone",
      issuer: "some issuer",
      client_id: "some client_id",
      key_set_url: "some key_set_url",
      auth_token_url: "some auth_token_url",
      auth_login_url: "some auth_login_url",
      auth_server: "some auth_server"
    }
    @update_attrs %{
      name: "some updated institution",
      country_code: "some updated country_code",
      institution_email: "some updated institution_email",
      institution_url: "some updated institution_url",
      timezone: "some updated timezone",
      issuer: "some updated issuer",
      client_id: "some updated client_id",
      key_set_url: "some updated key_set_url",
      auth_token_url: "some updated auth_token_url",
      auth_login_url: "some updated auth_login_url",
      auth_server: "some updated auth_server"
    }
    @invalid_attrs %{
      name: nil,
      country_code: nil,
      institution_email: nil,
      institution_url: nil,
      timezone: nil,
      issuer: nil,
      client_id: nil,
      key_set_url: nil,
      auth_token_url: nil,
      auth_login_url: nil,
      auth_server: nil
    }

    test "list_pending_registrations/0 returns all pending_registrations", %{
      pending_registration: pending_registration
    } do
      assert Institutions.list_pending_registrations() == [pending_registration]
    end

    test "count_pending_registrations/0 returns the total count of pending registrations" do
      assert Institutions.count_pending_registrations() == 1

      Institutions.create_pending_registration(@valid_attrs)

      assert Institutions.count_pending_registrations() == 2
    end

    test "get_pending_registration!/1 returns the pending_registration with given id", %{
      pending_registration: pending_registration
    } do
      assert Institutions.get_pending_registration!(pending_registration.id) ==
               pending_registration
    end

    test "create_pending_registration/1 with valid data creates a pending_registration" do
      assert {:ok, %PendingRegistration{} = pending_registration} =
               Institutions.create_pending_registration(@valid_attrs)

      assert pending_registration.name == "some institution"
    end

    test "create_pending_registration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Institutions.create_pending_registration(@invalid_attrs)
    end

    test "update_pending_registration/2 with valid data updates the pending_registration", %{
      pending_registration: pending_registration
    } do
      assert {:ok, %PendingRegistration{} = pending_registration} =
               Institutions.update_pending_registration(pending_registration, @update_attrs)

      assert pending_registration.name == "some updated institution"
    end

    test "update_pending_registration/2 with invalid data returns error changeset", %{
      pending_registration: pending_registration
    } do
      assert {:error, %Ecto.Changeset{}} =
               Institutions.update_pending_registration(pending_registration, @invalid_attrs)

      assert pending_registration ==
               Institutions.get_pending_registration!(pending_registration.id)
    end

    test "delete_pending_registration/1 deletes the pending_registration", %{
      pending_registration: pending_registration
    } do
      assert {:ok, %PendingRegistration{}} =
               Institutions.delete_pending_registration(pending_registration)

      assert_raise Ecto.NoResultsError, fn ->
        Institutions.get_pending_registration!(pending_registration.id)
      end
    end

    test "change_pending_registration/1 returns a pending_registration changeset", %{
      pending_registration: pending_registration
    } do
      assert %Ecto.Changeset{} = Institutions.change_pending_registration(pending_registration)
    end

    test "find_or_create_institution_by_normalized_url/1 find an institution with a similar url",
         %{institution: institution} do
      {:ok, same_institution} =
        Institutions.find_or_create_institution_by_normalized_url(%{
          country_code: "US",
          institution_email: "institution@example.edu",
          institution_url: "https://institution.example.edu/",
          name: "Example Institution",
          timezone: "US/Eastern"
        })

      assert same_institution.id == institution.id

      {:ok, same_institution} =
        Institutions.find_or_create_institution_by_normalized_url(%{
          country_code: "US",
          institution_email: "institution@example.edu",
          institution_url: "http://institution.example.edu",
          name: "Example Institution",
          timezone: "US/Eastern"
        })

      assert same_institution.id == institution.id

      {:ok, different_institution} =
        Institutions.find_or_create_institution_by_normalized_url(%{
          country_code: "US",
          institution_email: "institution@example.edu",
          institution_url: "http://different.example.edu",
          name: "Example Institution",
          timezone: "US/Eastern"
        })

      assert different_institution.id != institution.id
    end

    test "find_or_create_institution_by_normalized_url/1 uses the first existing institution if multiple institutions with similar urls exist",
         %{institution: first_institution} do
      _second_institution = institution_fixture()

      {:ok, result_institution} =
        Institutions.find_or_create_institution_by_normalized_url(%{
          country_code: "US",
          institution_email: "institution@example.edu",
          institution_url: "https://institution.example.edu/",
          name: "Example Institution",
          timezone: "US/Eastern"
        })

      assert result_institution.id == first_institution.id
    end

    test "approve_pending_registration/1 creates a new institution and registration and removes pending registration" do
      {:ok, %PendingRegistration{} = pending_registration} =
        Institutions.create_pending_registration(%{
          name: "New Institution",
          country_code: "US",
          institution_email: "institution@new.example.edu",
          institution_url: "http://new.example.edu",
          timezone: "US/Eastern",
          issuer: "new issuer",
          client_id: "new client_id",
          key_set_url: "new key_set_url",
          auth_token_url: "new auth_token_url",
          auth_login_url: "new auth_login_url",
          auth_server: "new auth_server"
        })

      {:ok, {%Institution{}, %Registration{}}} =
        Institutions.approve_pending_registration(pending_registration)

      assert Institutions.list_institutions()
             |> Enum.find(fn i -> i.institution_url == "http://new.example.edu" end) != nil

      assert Institutions.list_registrations() |> Enum.find(fn r -> r.issuer == "new issuer" end) !=
               nil

      assert Institutions.get_pending_registration_by_issuer_client_id(
               "some issuer",
               "some client_id"
             ) == nil
    end

    test "approve_pending_registration/1 creates registration using existing institution for similar institution_url and removes pending registration" do
      {:ok, %PendingRegistration{} = pending_registration} =
        Institutions.create_pending_registration(%{
          name: "New Institution",
          country_code: "US",
          institution_email: "institution@new.example.edu",
          institution_url: "http://institution.example.edu",
          timezone: "US/Eastern",
          issuer: "new issuer",
          client_id: "new client_id",
          key_set_url: "new key_set_url",
          auth_token_url: "new auth_token_url",
          auth_login_url: "new auth_login_url",
          auth_server: "new auth_server"
        })

      {:ok, {%Institution{}, %Registration{}}} =
        Institutions.approve_pending_registration(pending_registration)

      assert Institutions.list_institutions() |> Enum.count() == 1

      assert Institutions.list_registrations() |> Enum.find(fn r -> r.issuer == "new issuer" end) !=
               nil

      assert Institutions.get_pending_registration_by_issuer_client_id(
               "some issuer",
               "some client_id"
             ) == nil
    end
  end
end
