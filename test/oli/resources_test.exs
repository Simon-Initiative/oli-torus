defmodule Oli.ResourcesTest do
  use Oli.DataCase

  alias Oli.Resources


  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Course.Project
  alias Oli.Course.Family
  alias Oli.Publishing.Publication
  alias Oli.Resources.Resource
  alias Oli.Resources.ResourceFamily
  alias Oli.Resources.ResourceRevision

  describe "resources" do
    alias Oli.Resources.Resource

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{resource: resource, valid_attrs: valid_attrs, project: project, resource_family: resource_family}}
    end

    test "list_resources/0 returns all resources", %{resource: resource} do
      assert Resources.list_resources() == [resource]
    end

    test "get_resource!/1 returns the resource with given id", %{resource: resource}  do
      assert Resources.get_resource!(resource.id) == resource
    end

    test "new_project_resource/2 with valid data creates a resource", %{project: project, resource_family: resource_family} do
      assert %Ecto.Changeset{valid?: true} = Resources.new_project_resource(project, resource_family)
    end

    test "delete_resource/1 deletes the resource", %{resource: resource}  do
      assert {:ok, %Resource{}} = Resources.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource!(resource.id) end
    end

    test "change_resource/1 returns a resource changeset", %{resource: resource}  do
      assert %Ecto.Changeset{} = Resources.change_resource(resource)
    end
  end

  describe "resource_revisions" do
    alias Oli.Resources.ResourceRevision

    @valid_attrs %{objectives: [], children: [], content: [], deleted: true, slug: "some slug", title: "some title"}
    @update_attrs %{objectives: [], children: [], content: [], deleted: false, slug: "some updated slug", title: "some updated title"}
    @invalid_attrs %{children: nil, content: nil, deleted: nil, slug: nil, title: nil}


    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, _publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
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
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "another_slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{family_id: resource_family.id, project_id: project.id}) |> Repo.insert
      {:ok, _rev} = ResourceRevision.changeset(%ResourceRevision{}, %{resource_type_id: resource_type, author_id: author.id, resource_id: resource.id, objectives: [], children: [], content: [], deleted: false, slug: "another_slug", title: "some title"}) |> Repo.insert

      found = Resources.get_resource_from_slugs!("slug", "some slug")
      assert found.id == revision.resource_id

      found = Resources.get_resource_from_slugs!("another_slug", "another_slug")
      assert found.id == resource.id
    end

    test "list_resource_revisions/0 returns all resource_revisions", %{revision: revision} do
      assert Resources.list_resource_revisions() == [revision]
    end

    test "get_resource_revision!/1 returns the resource_revision with given id", %{revision: revision}  do
      assert Resources.get_resource_revision!(revision.id) == revision
    end

    test "create_resource_revision/1 with valid data creates a resource_revision", %{valid_attrs: valid_attrs}  do
      assert {:ok, %ResourceRevision{} = revision} = Resources.create_resource_revision(valid_attrs)
      assert revision.children == []
      assert revision.content == []
      assert revision.deleted == true
      assert revision.slug == "some slug"
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
      assert revision.slug == "some updated slug"
      assert revision.title == "some updated title"
    end

    test "update_resource_revision/2 with invalid data returns error changeset", %{revision: revision}  do
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource_revision(revision, @invalid_attrs)
      assert revision == Resources.get_resource_revision!(revision.id)
    end

    test "delete_resource_revision/1 deletes the resource_revision", %{revision: revision}  do
      assert {:ok, %ResourceRevision{}} = Resources.delete_resource_revision(revision)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource_revision!(revision.id) end
    end

    test "change_resource_revision/1 returns a resource_revision changeset", %{revision: revision}  do
      assert %Ecto.Changeset{} = Resources.change_resource_revision(revision)
    end
  end
end
