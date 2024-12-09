defmodule OliWeb.RegistrationControllerTest do
  use OliWeb.ConnCase

  alias Oli.Institutions

  @create_attrs %{
    auth_login_url: "some auth_login_url",
    auth_server: "some auth_server",
    auth_token_url: "some auth_token_url",
    client_id: "some client_id",
    issuer: "some issuer",
    key_set_url: "some key_set_url",
    line_items_service_domain: "some line_items_service_domain"
  }
  @update_attrs %{
    auth_login_url: "some updated auth_login_url",
    auth_server: "some updated auth_server",
    auth_token_url: "some updated auth_token_url",
    client_id: "some updated client_id",
    issuer: "some updated issuer",
    key_set_url: "some updated key_set_url",
    line_items_service_domain: "some updated line_items_service_domain"
  }
  @invalid_attrs %{
    auth_login_url: nil,
    auth_server: nil,
    auth_token_url: nil,
    client_id: nil,
    issuer: nil,
    key_set_url: nil,
    line_items_service_domain: nil
  }

  describe "new registration" do
    setup [:create_fixtures]

    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.registration_path(conn, :new))
      assert html_response(conn, 200) =~ "Create Registration"
    end
  end

  describe "create registration" do
    setup [:create_fixtures]

    test "redirects to show when data is valid", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.registration_path(conn, :create),
          registration: Map.put(@create_attrs, :issuer, "some other issuer")
        )

      assert redirected_to(conn) =~ "/admin/registrations/"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.registration_path(conn, :create), registration: @invalid_attrs)

      assert html_response(conn, 200) =~ "Create Registration"
    end
  end

  describe "edit registration" do
    setup [:create_fixtures]

    test "renders form for editing chosen registration", %{
      conn: conn,
      registration: registration
    } do
      conn = get(conn, Routes.registration_path(conn, :edit, registration))

      assert html_response(conn, 200) =~ "Edit Registration"
    end
  end

  describe "update registration" do
    setup [:create_fixtures]

    test "redirects when data is valid", %{
      conn: conn,
      registration: registration,
      admin: admin
    } do
      conn =
        put(
          conn,
          Routes.registration_path(conn, :update, registration),
          registration: @update_attrs
        )

      assert redirected_to(conn) =~ "/admin/registrations/"

      conn =
        recycle(conn)
        |> log_in_author(admin)

      conn = get(conn, Routes.registration_path(conn, :show, registration.id))
      assert html_response(conn, 200) =~ "some updated auth_login_url"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      registration: registration
    } do
      conn =
        put(
          conn,
          Routes.registration_path(conn, :update, registration),
          registration: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Edit Registration"
    end
  end

  describe "delete registration" do
    setup [:create_fixtures]

    test "deletes chosen registration", %{
      conn: conn,
      registration: registration,
      admin: admin
    } do
      conn =
        delete(
          conn,
          Routes.registration_path(conn, :delete, registration)
        )

      assert redirected_to(conn) ==
               Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView)

      assert_raise Ecto.NoResultsError, fn ->
        recycle(conn)
        |> log_in_author(admin)

        Institutions.get_registration!(registration.id)
      end
    end
  end

  defp create_fixtures(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    jwk = jwk_fixture()
    institution = institution_fixture()
    registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})

    # sign admin author in
    conn = log_in_author(conn, admin)

    %{conn: conn, registration: registration, institution: institution, admin: admin}
  end
end
