defmodule OliWeb.InstitutionControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti.Tool.Registration
  alias Oli.Lti.Tool.Deployment

  @create_attrs %{
    country_code: "some country_code",
    institution_email: "some institution_email",
    institution_url: "some institution_url",
    name: "some name"
  }
  @update_attrs %{
    country_code: "some updated country_code",
    institution_email: "some updated institution_email",
    institution_url: "some updated institution_url",
    name: "some updated name"
  }
  @invalid_attrs %{
    country_code: nil,
    institution_email: nil,
    institution_url: nil,
    name: nil
  }

  setup [:create_institution]

  describe "index" do
    test "lists all institutions", %{conn: conn} do
      conn = get(conn, ~p"/admin/institutions")
      assert html_response(conn, 200) =~ "some name"
    end
  end

  describe "new institution" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.institution_path(conn, :new))
      assert html_response(conn, 200) =~ "Register Institution"
    end
  end

  describe "create institution" do
    test "redirects to page index when data is valid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @create_attrs)

      assert redirected_to(conn) == ~p"/admin/institutions"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @invalid_attrs)
      assert html_response(conn, 200) =~ "Register Institution"
    end
  end

  describe "show institution" do
    test "renders institution details", %{conn: conn, institution: institution} do
      conn = get(conn, Routes.institution_path(conn, :show, institution))
      assert html_response(conn, 200) =~ "some name"

      assert html_response(conn, 200) =~
               "href=\"#{Routes.discount_path(OliWeb.Endpoint, :institution, institution.id)}\""
    end

    test "renders institution registration details", %{conn: conn, institution: institution} do
      jwk = jwk_fixture()

      %Registration{id: registration_id} = registration_fixture(%{tool_jwk_id: jwk.id})

      %Deployment{deployment_id: deployment_id} =
        deployment_fixture(%{institution_id: institution.id, registration_id: registration_id})

      conn = get(conn, Routes.institution_path(conn, :show, institution))
      assert html_response(conn, 200) =~ deployment_id
    end
  end

  describe "edit institution" do
    test "renders form for editing chosen institution", %{conn: conn, institution: institution} do
      conn = get(conn, Routes.institution_path(conn, :edit, institution))
      assert html_response(conn, 200) =~ "Edit Institution"
    end
  end

  describe "update institution" do
    test "redirects when data is valid", %{conn: conn, author: author, institution: institution} do
      conn =
        put(conn, Routes.institution_path(conn, :update, institution), institution: @update_attrs)

      assert redirected_to(conn) == Routes.institution_path(conn, :show, institution)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn = get(conn, Routes.institution_path(conn, :show, institution))
      assert html_response(conn, 200) =~ "some updated country_code"
    end

    test "renders errors when data is invalid", %{conn: conn, institution: institution} do
      conn =
        put(conn, Routes.institution_path(conn, :update, institution),
          institution: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Edit Institution"
    end
  end

  describe "delete institution" do
    test "deletes chosen institution", %{conn: conn, institution: institution} do
      conn = delete(conn, Routes.institution_path(conn, :delete, institution))
      assert redirected_to(conn) == ~p"/admin/institutions"

      institution_id = institution.id

      assert %Institution{id: ^institution_id} =
               Institutions.get_institution_by!(%{status: :deleted})
    end
  end

  defp create_institution(%{conn: conn}) do
    author =
      author_fixture(%{
        email: "test@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: Accounts.SystemRole.role_id().system_admin
      })

    create_attrs = Map.put(@create_attrs, :author_id, author.id)
    {:ok, institution} = create_attrs |> Institutions.create_institution()

    conn =
      log_in_author(conn, author)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
