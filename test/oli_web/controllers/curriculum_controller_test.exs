defmodule OliWeb.CurriculumControllerTest do
  use OliWeb.ConnCase

  setup [:project_seed]

  describe "index" do
    test "lists pages", %{conn: conn, project: project} do
      conn = get(conn, Routes.curriculum_path(conn, :index, project))
      assert html_response(conn, 200) =~ "Pages"
    end
  end

  describe "create page" do
    test "redirects back to curriculum with new page", %{conn: conn, project: project} do
      conn = post(conn, Routes.curriculum_path(conn, :create, project, %{"type" => "Unscored"}))
      assert redirected_to(conn) == Routes.curriculum_path(conn, :index, project)

      conn = get(conn, Routes.curriculum_path(conn, :index, project))
      assert html_response(conn, 200) =~ "Pages"
    end

  end

  describe "update page" do
    @tag :skip
    test "redirects when data is valid", %{conn: conn, project: project} do
      conn = put(conn, Routes.curriculum_path(conn, :update, project))
      assert redirected_to(conn) == Routes.curriculum_path(conn, :show, project)

      conn = get(conn, Routes.curriculum_path(conn, :show, project))
      assert html_response(conn, 200)
    end

    @tag :skip
    test "renders errors when data is invalid", %{conn: conn, project: project} do
      conn = put(conn, Routes.curriculum_path(conn, :update, project))
      assert html_response(conn, 200) =~ "Edit Page"
    end
  end

  def project_seed(%{conn: conn}) do
    seeds = Oli.Seeder.base_project_with_resource()
    conn = Plug.Test.init_test_session(conn, current_author_id: seeds.author.id)

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
