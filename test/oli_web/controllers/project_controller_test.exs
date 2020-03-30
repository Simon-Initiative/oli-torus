defmodule OliWeb.ProjectControllerTest do
  use OliWeb.ConnCase

  describe "authorization" do
    test "author cannot access project that doesn't exist"
    test "author can only access their projects"
  end

  describe "overview" do
    test "displays the page"
  end

  describe "objectives" do
    test "displays the page"
  end

  describe "curriculum" do
    test "displays the page"
  end

  describe "publish" do
    test "displays the page"
  end

  describe "insights" do
    test "displays the page"
  end

  describe "create a project" do
    test "creates a new family"
    test "creates a new project tied to the family"
    test "associates the currently logged in author with the new project"
    test "creates a new container resource"
    test "creates a new resource revision for the container"
    test "creates a new publication associated with the project and containing the container resource"
  end
end
