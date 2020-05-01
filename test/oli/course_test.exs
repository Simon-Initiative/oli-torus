defmodule Oli.CourseTest do
  use Oli.DataCase

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.{Family, Project}

  describe "projects basic" do

    @valid_attrs %{description: "some description", version: "1", title: "some title"}
    @update_attrs %{description: "some updated description", version: "1", title: "some updated title"}
    @invalid_attrs %{description: nil, slug: nil, title: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", title: "title", version: "1", family_id: family.id}) |> Repo.insert

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

    test "create project with invalid data returns error changeset" do
      empty_title = ""
      assert {:error, results} = Course.create_project(empty_title, author_fixture())
    end

    test "create_empty_project/1 with valid data creates a project", %{valid_attrs: valid_attrs} do
      assert {:ok, %Project{} = project} = create_empty_project(valid_attrs)
      assert project.description == "some description"
      assert project.slug == "some_title"
      assert project.title == "some title"
    end

    test "create_empty_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = create_empty_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project", %{project: project}  do
      assert {:ok, %Project{} = project} = Course.update_project(project, @update_attrs)
      assert project.description == "some updated description"
      assert project.slug == "title"   # The slug should never change
      assert project.title == "some updated title"
    end

    test "update_project/2 with invalid data returns error changeset", %{project: project}  do
      assert {:error, %Ecto.Changeset{}} = Course.update_project(project, @invalid_attrs)
      assert project == Course.get_project!(project.id)
    end
  end

  describe "families" do

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
  end

  describe "project creation with associations" do
    setup do
      author = author_fixture()
      {:ok, results} = Course.create_project("test project", author)
      {:ok, Map.put(results, :author, author)}
    end

    test "creates a new family", %{project_family: family} do
      assert !is_nil(family)
    end

    test "creates a new project tied to the family", %{project: project, project_family: family} do
      project = Repo.preload(project, [:family])
      assert project.family.slug == family.slug
    end

    test "associates the currently logged in author with the new project", %{author_project: author_project, project: project, author: author} do
      assert !is_nil(author_project)
      assert author_project.author_id == author.id
      assert author_project.project_id == project.id
      assert Repo.preload(author_project, [:project_role]).project_role.type == "owner"
    end

    test "creates a new container resource", %{resource_revision: revision} do
      assert revision.slug =~ "root_container"
    end

    test "creates a new resource revision for the container", %{resource: resource, resource_revision: resource_revision} do
      revision = Repo.preload(resource_revision, [:resource])
      assert revision.slug =~ "root_container"
      assert revision.resource == resource
    end

    test "project should always have an unpublished, 'active' publication", %{project: project} do
      assert Enum.find(Oli.Repo.preload(project, [:publications]).publications, &(&1.published == false))
    end

    test "creates a new publication associated with the project and containing the container resource", %{publication: publication, resource: resource, project: project} do

      publication = Repo.preload(publication, [:project])
      assert publication.project == project
      assert Repo.preload(publication, [:root_resource]).root_resource == resource

    end

  end
end
