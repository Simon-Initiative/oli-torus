defmodule OliWeb.InstitutionControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  @create_attrs %{country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", name: "some name", timezone: "some timezone"}
  @update_attrs %{country_code: "some updated country_code", institution_email: "some updated institution_email", institution_url: "some updated institution_url", name: "some updated name", timezone: "some updated timezone"}
  @invalid_attrs %{country_code: nil, institution_email: nil, institution_url: nil, name: nil, timezone: nil}

  setup do
    {:ok, user} = User.changeset(%User{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo"}) |> Repo.insert
    valid_attrs = Map.put(@valid_attrs, :user_id, user.id)
    {:ok, institution} = valid_attrs |> Accounts.create_institution()

    {:ok, %{institution: institution, user: user, valid_attrs: valid_attrs}}
  end


  def fixture(:institution) do
    {:ok, institution} = Accounts.create_institution(@create_attrs)
    institution
  end

  describe "index" do
    test "lists all institutions", %{conn: conn} do
      conn = get(conn, Routes.institution_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Institutions"
    end
  end

  describe "new institution" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.institution_path(conn, :new))
      assert html_response(conn, 200) =~ "New Institution"
    end
  end

  describe "create institution" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.institution_path(conn, :show, id)

      conn = get(conn, Routes.institution_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Institution"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.institution_path(conn, :create), institution: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Institution"
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

  defp create_institution(_) do
    institution = fixture(:institution)
    {:ok, institution: institution}
  end
end
