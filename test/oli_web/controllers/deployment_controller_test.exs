defmodule OliWeb.DeploymentControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Author
  alias Oli.Institutions

  @create_attrs %{deployment_id: "some deployment_id", registration_id: 1}
  @update_attrs %{deployment_id: "some updated deployment_id"}
  @invalid_attrs %{deployment_id: nil}

  describe "new deployment" do
    setup [:create_fixtures]

    test "renders form", %{conn: conn, registration: registration} do
      conn =
        get(
          conn,
          Routes.registration_deployment_path(
            conn,
            :new,
            registration.id
          )
        )

      assert html_response(conn, 200) =~ "Create Deployment"
    end
  end

  describe "create deployment" do
    setup [:create_fixtures]

    test "redirects to registration_path :show when data is valid", %{
      conn: conn,
      admin: admin,
      registration: registration,
      institution: institution
    } do
      conn =
        post(
          conn,
          Routes.registration_deployment_path(
            conn,
            :create,
            registration.id
          ),
          deployment: Map.put(@create_attrs, :institution_id, institution.id)
        )

      assert redirected_to(conn) == Routes.registration_path(conn, :show, registration.id)

      # validate the new deployment exists on the institution details page
      conn =
        recycle(conn)
        |> log_in_author(admin)

      conn = get(conn, Routes.institution_path(conn, :show, institution.id))
      assert html_response(conn, 200) =~ "some deployment_id"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      registration: registration
    } do
      conn =
        post(
          conn,
          Routes.registration_deployment_path(
            conn,
            :create,
            registration.id
          ),
          deployment: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Create Deployment"
    end
  end

  describe "edit deployment" do
    setup [:create_fixtures]

    test "renders form for editing chosen deployment", %{
      conn: conn,
      deployment: deployment,
      registration: registration
    } do
      conn =
        get(
          conn,
          Routes.registration_deployment_path(
            conn,
            :edit,
            registration.id,
            deployment
          )
        )

      assert html_response(conn, 200) =~ "Edit Deployment"
    end
  end

  describe "update deployment" do
    setup [:create_fixtures]

    test "redirects when data is valid", %{
      conn: conn,
      deployment: deployment,
      registration: registration,
      institution: institution,
      admin: admin
    } do
      conn =
        put(
          conn,
          Routes.registration_deployment_path(
            conn,
            :update,
            registration.id,
            deployment
          ),
          deployment: @update_attrs
        )

      assert redirected_to(conn) == Routes.registration_path(conn, :show, registration.id)

      conn =
        recycle(conn)
        |> log_in_author(admin)

      conn = get(conn, Routes.institution_path(conn, :show, institution.id))
      assert html_response(conn, 200) =~ "some updated deployment_id"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      deployment: deployment,
      registration: registration
    } do
      conn =
        put(
          conn,
          Routes.registration_deployment_path(
            conn,
            :update,
            registration.id,
            deployment
          ),
          deployment: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Edit Deployment"
    end
  end

  describe "delete deployment" do
    setup [:create_fixtures]

    test "deletes chosen deployment", %{
      conn: conn,
      deployment: deployment,
      registration: registration
    } do
      conn =
        delete(
          conn,
          Routes.registration_deployment_path(
            conn,
            :delete,
            registration.id,
            deployment
          )
        )

      assert redirected_to(conn) == Routes.registration_path(conn, :show, registration.id)

      assert_raise Ecto.NoResultsError, fn ->
        Institutions.get_institution!(deployment.id)
      end
    end
  end

  defp create_fixtures(%{conn: conn}) do
    {:ok, admin} =
      Author.noauth_changeset(%Author{}, %{
        email: "test@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: SystemRole.role_id().system_admin
      })
      |> Repo.insert()

    jwk = jwk_fixture()
    institution = institution_fixture()
    registration = registration_fixture(%{tool_jwk_id: jwk.id})

    deployment =
      deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

    # sign admin author in
    conn =
      conn
      |> log_in_author(admin)

    %{
      conn: conn,
      deployment: deployment,
      registration: registration,
      institution: institution,
      admin: admin
    }
  end
end
