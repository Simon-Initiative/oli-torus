defmodule OliWeb.ObjectiveControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo
  alias Oli.Course.Project

  alias Oli.Learning
  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveFamily
  alias Oli.Learning.ObjectiveRevision

  @basic_get_routes [:create, :update, :delete]
  setup [:author_project_objective_fixture]
  @valid_attrs %{title: "default title"}
  @invalid_attrs %{title: ""}
  @update_attrs %{title: "updated default title"}

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

  describe "update objective" do
    test "performs update when data is valid", %{conn: conn, project: project, objective_revision: objective_revision} do
      put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.id), objective: @update_attrs)
      assert Repo.get_by(ObjectiveRevision, @update_attrs)
    end

    test "prevents update when data is invalid", %{conn: conn, project: project, objective_revision: objective_revision} do
      put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.id), objective: @invalid_attrs)
      refute Repo.get_by(ObjectiveRevision, @invalid_attrs)
    end

    test "x-status value 'success' on success", %{conn: conn, project: project, objective_revision: objective_revision} do
      conn = put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.id), objective: @update_attrs)
      assert get_req_header(conn, "x-status") == ["success"]
    end

    test "x-status value 'failed' on failure", %{conn: conn, project: project, objective_revision: objective_revision} do
      conn = put(conn, Routes.objective_path(conn, :update, project.slug, objective_revision.id), objective: @invalid_attrs)
      assert get_req_header(conn, "x-status") == ["failed"]
    end
  end

  describe "mark objective deleted" do
    test "marks objective_revision as deleted", %{conn: conn, project: project, objective_revision: objective_revision} do
      delete(conn, Routes.objective_path(conn, :delete, project.slug, objective_revision.id))
      deleted_revision = Learning.get_objective_revision!(objective_revision.id)
      assert deleted_revision.deleted == true
    end
  end
end
