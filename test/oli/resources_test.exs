defmodule Oli.ResourcesTest do
  use Oli.DataCase

  alias Oli.Accounts.{SystemRole, Institution, Author}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing.Publication
  alias Oli.Authoring.Resources
  alias Oli.Authoring.Resources.{Resource, ResourceFamily, ResourceRevision}

  describe "resources" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "list_resources/0 returns all resources", %{resource: resource} do
      assert Enum.find(Resources.list_resources(), false, & (&1 == resource))
    end

    test "get_resource!/1 returns the resource with given id", %{resource: resource}  do
      assert Resources.get_resource!(resource.id) == resource
    end

    test "create_project_resource/2 with valid data creates a new resource for a project and all the necessary constructs", %{author: author, project: project} do
      resource_type = Resources.list_resource_types() |> hd
      attrs = %{
        objectives: [],
        children: [],
        content: [],
        title: "a new title",
      }
      assert {:ok, %{resource: resource, revision: revision, project: _, family: _, mapping: _} = result} = Resources.create_project_resource(attrs, resource_type, author, project)

      resource_id = resource.id
      assert %{
        objectives: [],
        children: [],
        content: [],
        title: "a new title",
        slug: "a_new_title",
        resource_id: ^resource_id
      } = revision
    end

    test "delete_resource/1 deletes the resource", %{project: project, resource_family: resource_family}  do
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      assert {:ok, %Resource{}} = Resources.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource!(resource.id) end
    end

    test "create_new_resource/2 with valid data creates a resource", %{project: project, resource_family: resource_family} do
      assert {:ok, resource} = Resources.create_new_resource(project, resource_family)
    end

    test "initial_resource_setup(author, project) creates a resource with the correct associations", %{author: author, project: project} do
      {:ok, %{resource: resource, resource_revision: revision, resource_family: family}} = Resources.initial_resource_setup(author, project)
      assert Repo.preload(resource, :family).family == family
      assert Repo.preload(revision, :resource_type).resource_type == Resources.resource_type().container
      assert Repo.preload(revision, :resource).resource == resource
    end

    test "mark revision deleted", %{project: project, revision: revision, author: author} do
      refute revision.deleted
      {:ok, new_revision} = Resources.mark_revision_deleted(project.slug, revision.slug, author.id)
      assert new_revision.deleted
    end

    test "list_all_pages(project)", %{project: project, revision: revision} do
      pages = Resources.list_all_pages(project)
      refute Enum.empty?(pages)
      assert Enum.find(pages, & &1 == revision)
    end

  end

  describe "resource_revisions" do


    @valid_attrs %{objectives: [], children: [], content: [], deleted: true, slug: "some slug", title: "some title"}
    @update_attrs %{objectives: [], children: [], content: [], deleted: false, slug: "some updated slug", title: "some updated title"}
    @invalid_attrs %{children: nil, content: nil, deleted: nil, slug: nil, title: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{family_id: resource_family.id, project_id: project.id}) |> Repo.insert

      resource_type = Resources.list_resource_types() |> hd

      valid_attrs = Map.put(@valid_attrs, :author_id, author.id)
        |> Map.put(:resource_id, resource.id)
        |> Map.put(:previous_revision_id, nil)
        |> Map.put(:resource_type_id, resource_type.id)

      {:ok, revision} = valid_attrs |> Resources.create_resource_revision()

      {:ok, %{revision: revision, valid_attrs: valid_attrs, resource_type: resource_type.id, family: family, author: author}}
    end

    test "get_resource_from_slugs/2 returns correct resource", %{revision: revision, resource_type: resource_type, family: family, author: author} do

      # Add another project, resource, and revision
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "another_title", title: "another_title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{family_id: resource_family.id, project_id: project.id}) |> Repo.insert
      {:ok, _rev} = ResourceRevision.changeset(%ResourceRevision{}, %{resource_type_id: resource_type, author_id: author.id, resource_id: resource.id, objectives: [], children: [], content: [], deleted: false, slug: "another_slug", title: "another_slug"}) |> Repo.insert

      found = Resources.get_resource_from_slugs("title", "some_title")
      assert found.id == revision.resource_id

      found = Resources.get_resource_from_slugs("another_title", "another_slug")
      assert found.id == resource.id

      found = Resources.get_resource_from_slugs("another_title", "missing")
      assert found == nil
    end

    test "get_resource_revision!/1 returns the resource_revision with given id", %{revision: revision}  do
      assert Resources.get_resource_revision!(revision.id) == revision
    end

    test "create_resource_revision/1 with valid data creates a resource_revision", %{valid_attrs: valid_attrs}  do
      assert {:ok, %ResourceRevision{} = revision} = Resources.create_resource_revision(valid_attrs)
      assert revision.children == []
      assert revision.content == []
      assert revision.deleted == true
      assert revision.title == "some title"
    end

    test "create_resource_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_resource_revision(@invalid_attrs)
    end

    test "update_resource_revision/2 with valid data updates the resource_revision", %{revision: revision}  do
      assert {:ok, %ResourceRevision{} = revision} = Resources.update_resource_revision(revision, @update_attrs)
      assert revision.children == []
      assert revision.content == []
      assert revision.deleted == false
      assert revision.slug == "some_updated_title"
      assert revision.title == "some updated title"
    end

    test "update_resource_revision/2 with invalid data returns error changeset", %{revision: revision}  do
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource_revision(revision, @invalid_attrs)
      assert revision == Resources.get_resource_revision!(revision.id)
    end

  end
end
