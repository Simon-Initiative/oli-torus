defmodule Oli.CourseTest do
  use Oli.DataCase

  alias Oli.Course
  alias Oli.Course.Family
  alias Oli.Course.Project

  describe "projects" do
    alias Oli.Course.Project

    @valid_attrs %{description: "some description", slug: "some slug", version: "1", title: "some title"}
    @update_attrs %{description: "some updated description", version: "1", slug: "some updated slug", title: "some updated title"}
    @invalid_attrs %{description: nil, slug: nil, title: nil}

    # def project_fixture(attrs \\ %{}) do
    #   {:ok, project} =
    #     attrs
    #     |> Enum.into(@valid_attrs)
    #     |> Course.create_project()

    #   project
    # end

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :family_id, family.id)
        |> Map.put(:project_id, project.id)

      {:ok, %{project: project, family: family, valid_attrs: valid_attrs}}
    end


    test "list_projects/0 returns all projects", %{project: project} do
      assert Course.list_projects() == [project]
    end

    test "get_project!/1 returns the project with given id", %{project: project} do
      assert Course.get_project!(project.id) == project
    end

    test "create_empty_project/1 with valid data creates a project", %{valid_attrs: valid_attrs} do
      assert {:ok, %Project{} = project} = create_empty_project(valid_attrs)
      assert project.description == "some description"
      assert project.slug == "some slug"
      assert project.title == "some title"
    end

    test "create_empty_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = create_empty_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project", %{project: project}  do
      assert {:ok, %Project{} = project} = Course.update_project(project, @update_attrs)
      assert project.description == "some updated description"
      assert project.slug == "some updated slug"
      assert project.title == "some updated title"
    end

    test "update_project/2 with invalid data returns error changeset", %{project: project}  do
      assert {:error, %Ecto.Changeset{}} = Course.update_project(project, @invalid_attrs)
      assert project == Course.get_project!(project.id)
    end

    test "delete_project/1 deletes the project", %{project: project}  do
      assert {:ok, %Project{}} = Course.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Course.get_project!(project.id) end
    end

    test "change_project/1 returns a project changeset", %{project: project}  do
      assert %Ecto.Changeset{} = Course.change_project(project)
    end
  end

  describe "families" do
    alias Oli.Course.Family

    @valid_attrs %{description: "some description", slug: "some slug", title: "some title"}
    @update_attrs %{description: "some updated description", slug: "some updated slug", title: "some updated title"}
    @invalid_attrs %{description: nil, slug: nil, title: nil}

    def family_fixture(attrs \\ %{}) do
      {:ok, family} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Course.create_family()

      family
    end

    test "list_families/0 returns all families" do
      family = family_fixture()
      assert Course.list_families() == [family]
    end

    test "get_family!/1 returns the family with given id" do
      family = family_fixture()
      assert Course.get_family!(family.id) == family
    end

    test "create_family/1 with valid data creates a family" do
      assert {:ok, %Family{} = family} = Course.create_family(@valid_attrs)
      assert family.description == "some description"
      assert family.slug == "some slug"
      assert family.title == "some title"
    end

    test "create_family/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Course.create_family(@invalid_attrs)
    end

    test "update_family/2 with valid data updates the family" do
      family = family_fixture()
      assert {:ok, %Family{} = family} = Course.update_family(family, @update_attrs)
      assert family.description == "some updated description"
      assert family.slug == "some updated slug"
      assert family.title == "some updated title"
    end

    test "update_family/2 with invalid data returns error changeset" do
      family = family_fixture()
      assert {:error, %Ecto.Changeset{}} = Course.update_family(family, @invalid_attrs)
      assert family == Course.get_family!(family.id)
    end

    test "delete_family/1 deletes the family" do
      family = family_fixture()
      assert {:ok, %Family{}} = Course.delete_family(family)
      assert_raise Ecto.NoResultsError, fn -> Course.get_family!(family.id) end
    end

    test "change_family/1 returns a family changeset" do
      family = family_fixture()
      assert %Ecto.Changeset{} = Course.change_family(family)
    end
  end
end
