defmodule OliWeb.InstitutionControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Institutions

  @create_attrs %{country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", name: "some name", timezone: "some timezone"}
  @update_attrs %{country_code: "some updated country_code", institution_email: "some updated institution_email", institution_url: "some updated institution_url", name: "some updated name", timezone: "some updated timezone"}
  @invalid_attrs %{country_code: nil, institution_email: nil, institution_url: nil, name: nil, timezone: nil}

  describe "index" do
    setup [:create_institution]

    test "lists all institutions", %{conn: conn} do
      conn = get(conn, Routes.institution_path(conn, :index))
      assert html_response(conn, 200) =~ "My Institutions"
    end
  end

  describe "new institution" do
    setup [:create_institution]

    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.institution_path(conn, :new))
      assert html_response(conn, 200) =~ "Register Institution"
    end
  end

  describe "create institution" do
    setup [:create_institution]

    test "redirects to page index when data is valid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @create_attrs)

      assert redirected_to(conn) == Routes.static_page_path(conn, :index)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @invalid_attrs)
      assert html_response(conn, 200) =~ "Register Institution"
    end
  end

  describe "edit institution" do
    setup [:create_institution]

    test "renders form for editing chosen institution", %{conn: conn, institution: institution} do
      conn = get(conn, Routes.institution_path(conn, :edit, institution))
      assert html_response(conn, 200) =~ "Edit Institution"
    end
  end

  describe "update institution" do
    setup [:create_institution]

    test "redirects when data is valid", %{conn: conn, institution: institution} do
      conn = put(conn, Routes.institution_path(conn, :update, institution), institution: @update_attrs)
      assert redirected_to(conn) == Routes.institution_path(conn, :show, institution)

      conn = get(conn, Routes.institution_path(conn, :show, institution))
      assert html_response(conn, 200) =~ "some updated country_code"
    end

    test "renders errors when data is invalid", %{conn: conn, institution: institution} do
      conn = put(conn, Routes.institution_path(conn, :update, institution), institution: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Institution"
    end
  end

  describe "delete institution" do
    setup [:create_institution]

    test "deletes chosen institution", %{conn: conn, institution: institution} do
      conn = delete(conn, Routes.institution_path(conn, :delete, institution))
      assert redirected_to(conn) == Routes.institution_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.institution_path(conn, :show, institution))
      end
    end
  end

  @create_attrs %{auth_login_url: "some auth_login_url", auth_server: "some auth_server", auth_token_url: "some auth_token_url", client_id: "some client_id", issuer: "some issuer", key_set_url: "some key_set_url", kid: "some kid"}
  @update_attrs %{auth_login_url: "some updated auth_login_url", auth_server: "some updated auth_server", auth_token_url: "some updated auth_token_url", client_id: "some updated client_id", issuer: "some updated issuer", key_set_url: "some updated key_set_url", kid: "some updated kid"}
  @invalid_attrs %{auth_login_url: nil, auth_server: nil, auth_token_url: nil, client_id: nil, issuer: nil, key_set_url: nil, kid: nil}

  def registration_fixture(:registration) do
    {:ok, registration} = Institutions.create_registration(@create_attrs)
    registration
  end

  describe "new registration" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.registration_path(conn, :new))
      assert html_response(conn, 200) =~ "New Registration"
    end
  end

  describe "create registration" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.registration_path(conn, :create), registration: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.registration_path(conn, :show, id)

      conn = get(conn, Routes.registration_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Registration"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.registration_path(conn, :create), registration: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Registration"
    end
  end

  describe "edit registration" do
    setup [:create_registration]

    test "renders form for editing chosen registration", %{conn: conn, registration: registration} do
      conn = get(conn, Routes.registration_path(conn, :edit, registration))
      assert html_response(conn, 200) =~ "Edit Registration"
    end
  end

  describe "update registration" do
    setup [:create_registration]

    test "redirects when data is valid", %{conn: conn, registration: registration} do
      conn = put(conn, Routes.registration_path(conn, :update, registration), registration: @update_attrs)
      assert redirected_to(conn) == Routes.registration_path(conn, :show, registration)

      conn = get(conn, Routes.registration_path(conn, :show, registration))
      assert html_response(conn, 200) =~ "some updated auth_login_url"
    end

    test "renders errors when data is invalid", %{conn: conn, registration: registration} do
      conn = put(conn, Routes.registration_path(conn, :update, registration), registration: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Registration"
    end
  end

  describe "delete registration" do
    setup [:create_registration]

    test "deletes chosen registration", %{conn: conn, registration: registration} do
      conn = delete(conn, Routes.registration_path(conn, :delete, registration))
      assert redirected_to(conn) == Routes.registration_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.registration_path(conn, :show, registration))
      end
    end
  end

  @create_attrs %{deployment_id: "some deployment_id"}
  @update_attrs %{deployment_id: "some updated deployment_id"}
  @invalid_attrs %{deployment_id: nil}

  def deployment_fixture(:deployment) do
    {:ok, deployment} = Institutions.create_deployment(@create_attrs)
    deployment
  end

  describe "index" do
    test "lists all deployments", %{conn: conn} do
      conn = get(conn, Routes.deployment_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Deployments"
    end
  end

  describe "new deployment" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.deployment_path(conn, :new))
      assert html_response(conn, 200) =~ "New Deployment"
    end
  end

  describe "create deployment" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.deployment_path(conn, :create), deployment: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.deployment_path(conn, :show, id)

      conn = get(conn, Routes.deployment_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Deployment"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.deployment_path(conn, :create), deployment: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Deployment"
    end
  end

  describe "edit deployment" do
    setup [:create_deployment]

    test "renders form for editing chosen deployment", %{conn: conn, deployment: deployment} do
      conn = get(conn, Routes.deployment_path(conn, :edit, deployment))
      assert html_response(conn, 200) =~ "Edit Deployment"
    end
  end

  describe "update deployment" do
    setup [:create_deployment]

    test "redirects when data is valid", %{conn: conn, deployment: deployment} do
      conn = put(conn, Routes.deployment_path(conn, :update, deployment), deployment: @update_attrs)
      assert redirected_to(conn) == Routes.deployment_path(conn, :show, deployment)

      conn = get(conn, Routes.deployment_path(conn, :show, deployment))
      assert html_response(conn, 200) =~ "some updated deployment_id"
    end

    test "renders errors when data is invalid", %{conn: conn, deployment: deployment} do
      conn = put(conn, Routes.deployment_path(conn, :update, deployment), deployment: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Deployment"
    end
  end

  describe "delete deployment" do
    setup [:create_deployment]

    test "deletes chosen deployment", %{conn: conn, deployment: deployment} do
      conn = delete(conn, Routes.deployment_path(conn, :delete, deployment))
      assert redirected_to(conn) == Routes.deployment_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.deployment_path(conn, :show, deployment))
      end
    end
  end

  defp create_deployment(_) do
    deployment = deployment_fixture(:deployment)
    %{deployment: deployment}
  end

  defp create_registration(_) do
    registration = registration_fixture(:registration)
    %{registration: registration}
  end

  defp create_institution(%{ conn: conn  }) do
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: Accounts.SystemRole.role_id.author}) |> Repo.insert
    create_attrs = Map.put(@create_attrs, :author_id, author.id)
    {:ok, institution} = create_attrs |> Accounts.create_institution()

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
