defmodule OliWeb.ResourceControllerTest do
  use OliWeb.ConnCase

  setup [:project_seed]

  describe "edit" do
    test "renders resource editor", %{conn: conn, project: project, revision1: revision} do

      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, revision.slug))
      assert html_response(conn, 200) =~ "Page Editor"
    end

    test "renders error when resource does not exist", %{conn: conn, project: project} do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, "does_not_exist"))
      assert html_response(conn, 200) =~ "Not Found"
    end
  end

  describe "update resource" do
    test "valid response on valid update", %{conn: conn, project: project, revision1: revision} do
      conn = put(conn, Routes.resource_path(conn, :update, project.slug, revision.slug, %{ "update" => %{"title" => "new title" }}))
      assert %{ "type" => "success" } = json_response(conn, 200)
    end

    test "error response on invalid update", %{conn: conn, project: project} do
      conn = put(conn, Routes.resource_path(conn, :update, project.slug, "does_not_exist", %{ "update" => %{"title" => "new title" }}))
      assert response(conn, 404)
    end
  end

  def project_seed(%{conn: conn}) do
    seeds = Oli.Seeder.base_project_with_resource2()
    conn = Plug.Test.init_test_session(conn, current_author_id: seeds.author.id)

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
