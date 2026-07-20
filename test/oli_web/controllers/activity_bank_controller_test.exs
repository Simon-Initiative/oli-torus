defmodule OliWeb.ActivityBankControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  setup [:project_seed]

  describe "index" do
    test "can launch activity bank editor", %{conn: conn, project: project} do
      conn = get(conn, Routes.activity_bank_path(conn, :index, project.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.ActivityBank\" data-react-props=\""
    end

    test "shows revision history link for admin users", %{conn: conn, project: project} do
      admin_author =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)

      conn = conn |> log_in_author(admin_author)
      conn = get(conn, Routes.activity_bank_path(conn, :index, project.slug))

      assert html_response(conn, 200) =~ ~s[&quot;revisionHistoryLink&quot;:true]
    end

    test "does not show revision history link for non-admin users", %{
      conn: conn,
      project: project
    } do
      conn = get(conn, Routes.activity_bank_path(conn, :index, project.slug))

      assert html_response(conn, 200) =~ ~s[&quot;revisionHistoryLink&quot;:false]
    end

    test "returns not found for non-existent project", %{conn: conn} do
      conn = get(conn, Routes.activity_bank_path(conn, :index, "non-existent-project"))

      assert response(conn, 302)
    end
  end

  def project_seed(%{conn: conn}) do
    map = Oli.Seeder.base_project_with_resource2()

    conn =
      log_in_author(
        conn,
        map.author
      )

    {:ok, Map.merge(%{conn: conn}, map)}
  end
end
