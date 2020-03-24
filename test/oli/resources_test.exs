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
  alias Oli.Resources.ResourceRevision
  alias Oli.Resources.ResourceType

  describe "resources" do
    alias Oli.Resources.Resource

    @valid_attrs %{slug: "some slug"}
    @update_attrs %{slug: "some updated slug"}
    @invalid_attrs %{slug: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, resource} = Resource.changeset(%Resource{}, %{slug: "slug", project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{resource: resource, valid_attrs: valid_attrs}}
    end

    test "list_resources/0 returns all resources", %{resource: resource} do
      assert Resources.list_resources() == [resource]
    end

    test "get_resource!/1 returns the resource with given id", %{resource: resource}  do
      assert Resources.get_resource!(resource.id) == resource
    end

    test "create_resource/1 with valid data creates a resource", %{valid_attrs: valid_attrs} do
      assert {:ok, %Resource{} = resource} = Resources.create_resource(valid_attrs)
      assert resource.slug == "some slug"
    end

    test "create_resource/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_resource(@invalid_attrs)
    end

    test "update_resource/2 with valid data updates the resource", %{resource: resource}  do
      assert {:ok, %Resource{} = resource} = Resources.update_resource(resource, @update_attrs)
      assert resource.slug == "some updated slug"
    end

    test "update_resource/2 with invalid data returns error changeset", %{resource: resource}  do
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource(resource, @invalid_attrs)
      assert resource == Resources.get_resource!(resource.id)
    end

    test "delete_resource/1 deletes the resource", %{resource: resource}  do
      assert {:ok, %Resource{}} = Resources.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource!(resource.id) end
    end

    test "change_resource/1 returns a resource changeset", %{resource: resource}  do
      assert %Ecto.Changeset{} = Resources.change_resource(resource)
    end
  end

  describe "resource_types" do
    alias Oli.Resources.ResourceType

    @valid_attrs %{type: "some type"}
    @update_attrs %{type: "some updated type"}
    @invalid_attrs %{type: nil}

    def resource_type_fixture(attrs \\ %{}) do
      {:ok, resource_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Resources.create_resource_type()

      resource_type
    end

    test "list_resource_types/0 returns all resource_types" do
      resource_type = resource_type_fixture()
      assert length(Resources.list_resource_types()) == 3
    end

    test "get_resource_type!/1 returns the resource_type with given id" do
      resource_type = resource_type_fixture()
      assert Resources.get_resource_type!(resource_type.id) == resource_type
    end

    test "create_resource_type/1 with valid data creates a resource_type" do
      assert {:ok, %ResourceType{} = resource_type} = Resources.create_resource_type(@valid_attrs)
      assert resource_type.type == "some type"
    end

    test "create_resource_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_resource_type(@invalid_attrs)
    end

    test "update_resource_type/2 with valid data updates the resource_type" do
      resource_type = resource_type_fixture()
      assert {:ok, %ResourceType{} = resource_type} = Resources.update_resource_type(resource_type, @update_attrs)
      assert resource_type.type == "some updated type"
    end

    test "update_resource_type/2 with invalid data returns error changeset" do
      resource_type = resource_type_fixture()
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource_type(resource_type, @invalid_attrs)
      assert resource_type == Resources.get_resource_type!(resource_type.id)
    end

    test "delete_resource_type/1 deletes the resource_type" do
      resource_type = resource_type_fixture()
      assert {:ok, %ResourceType{}} = Resources.delete_resource_type(resource_type)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource_type!(resource_type.id) end
    end

    test "change_resource_type/1 returns a resource_type changeset" do
      resource_type = resource_type_fixture()
      assert %Ecto.Changeset{} = Resources.change_resource_type(resource_type)
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
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{slug: "slug", project_id: project.id}) |> Repo.insert

      resource_type = Resources.list_resource_types() |> hd

      valid_attrs = Map.put(@valid_attrs, :author_id, author.id)
        |> Map.put(:resource_id, resource.id)
        |> Map.put(:previous_revision_id, nil)
        |> Map.put(:resource_type_id, resource_type.id)

      {:ok, revision} = valid_attrs |> Resources.create_resource_revision()

      {:ok, %{revision: revision, valid_attrs: valid_attrs}}
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
