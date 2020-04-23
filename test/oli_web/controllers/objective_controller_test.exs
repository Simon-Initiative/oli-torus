defmodule OliWeb.ObjectiveControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Publishing

  setup [:author_project_objective_fixture]
  @valid_attrs %{title: "default title"}
  @invalid_attrs %{title: ""}
  @update_attrs %{title: "updated default title"}
  @sub_valid_attrs %{title: "sub-objective default title"}

  describe "create objective" do
    test "x-status header with value 'success' when data is valid", %{conn: conn, project: project} do
      conn = post(conn, Routes.objective_path(conn, :create, project.slug), objective: @valid_attrs)
      assert get_req_header(conn, "x-status") == ["success"]
    end

    test "x-status header with value 'failed' when data is invalid", %{conn: conn, project: project} do
      conn = post(conn, Routes.objective_path(conn, :create, project.slug), objective: @invalid_attrs)
      assert get_req_header(conn, "x-status") == ["failed"]
    end
  end

  describe "create sub-objective" do
    test "sub-objective x-status header with value 'success' when data is valid", %{conn: conn, project: project, objective_revision: parent_objective_revision} do

      sub_objective_valid_attrs = Map.merge(@sub_valid_attrs, %{parent_slug: parent_objective_revision.slug})
      conn = post(conn, Routes.objective_path(conn, :create, project.slug), objective: sub_objective_valid_attrs)

      parent = hd(Publishing.get_unpublished_revisions(project, [parent_objective_revision.resource_id]))

      child = Repo.get_by(Revision, @sub_valid_attrs)
      assert Enum.member?(parent.children, child.resource_id)
      assert get_req_header(conn, "x-status") == ["success"]
    end
  end

  describe "update objective" do
    test "performs update when data is valid", %{conn: conn, project: project, objective_revision: objective_revision} do
      put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.slug), objective: @update_attrs)
      assert Repo.get_by(Revision, @update_attrs)
    end

    test "prevents update when data is invalid", %{conn: conn, project: project, objective_revision: objective_revision} do
      put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.slug), objective: @invalid_attrs)
      refute Repo.get_by(Revision, @invalid_attrs)
    end

    test "x-status value 'success' on success", %{conn: conn, project: project, objective_revision: objective_revision} do
      conn = put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.slug), objective: @update_attrs)
      assert get_req_header(conn, "x-status") == ["success"]
    end

    test "x-status value 'failed' on failure", %{conn: conn, project: project, objective_revision: objective_revision} do
      conn = put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.slug), objective: @invalid_attrs)
      assert get_req_header(conn, "x-status") == ["failed"]
    end
  end

  describe "mark objective deleted" do
    test "marks objective_revision as deleted", %{conn: conn, project: project, objective_revision: objective_revision} do
      delete(conn, Routes.objective_path(conn, :delete, project.slug, objective_revision.slug))

      deleted_revision = hd(Publishing.get_unpublished_revisions(project, [objective_revision.resource_id]))

      assert deleted_revision.deleted == true
    end
  end
end
