defmodule OliWeb.InstitutionControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

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

  defp create_institution(%{ conn: conn  }) do
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: Accounts.SystemRole.role_id.author}) |> Repo.insert
    create_attrs = Map.put(@create_attrs, :author_id, author.id)
    {:ok, institution} = create_attrs |> Accounts.create_institution()

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
