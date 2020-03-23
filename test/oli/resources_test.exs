defmodule Oli.ResourcesTest do
  use Oli.DataCase

  alias Oli.Resources

  describe "resources" do
    alias Oli.Resources.Resource

    @valid_attrs %{slug: "some slug"}
    @update_attrs %{slug: "some updated slug"}
    @invalid_attrs %{slug: nil}

    def resource_fixture(attrs \\ %{}) do
      {:ok, resource} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Resources.create_resource()

      resource
    end

    test "list_resources/0 returns all resources" do
      resource = resource_fixture()
      assert Resources.list_resources() == [resource]
    end

    test "get_resource!/1 returns the resource with given id" do
      resource = resource_fixture()
      assert Resources.get_resource!(resource.id) == resource
    end

    test "create_resource/1 with valid data creates a resource" do
      assert {:ok, %Resource{} = resource} = Resources.create_resource(@valid_attrs)
      assert resource.slug == "some slug"
    end

    test "create_resource/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_resource(@invalid_attrs)
    end

    test "update_resource/2 with valid data updates the resource" do
      resource = resource_fixture()
      assert {:ok, %Resource{} = resource} = Resources.update_resource(resource, @update_attrs)
      assert resource.slug == "some updated slug"
    end

    test "update_resource/2 with invalid data returns error changeset" do
      resource = resource_fixture()
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource(resource, @invalid_attrs)
      assert resource == Resources.get_resource!(resource.id)
    end

    test "delete_resource/1 deletes the resource" do
      resource = resource_fixture()
      assert {:ok, %Resource{}} = Resources.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource!(resource.id) end
    end

    test "change_resource/1 returns a resource changeset" do
      resource = resource_fixture()
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
      assert Resources.list_resource_types() == [resource_type]
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

    @valid_attrs %{children: %{}, content: %{}, deleted: true, slug: "some slug", title: "some title"}
    @update_attrs %{children: %{}, content: %{}, deleted: false, slug: "some updated slug", title: "some updated title"}
    @invalid_attrs %{children: nil, content: nil, deleted: nil, slug: nil, title: nil}

    def resource_revision_fixture(attrs \\ %{}) do
      {:ok, resource_revision} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Resources.create_resource_revision()

      resource_revision
    end

    test "list_resource_revisions/0 returns all resource_revisions" do
      resource_revision = resource_revision_fixture()
      assert Resources.list_resource_revisions() == [resource_revision]
    end

    test "get_resource_revision!/1 returns the resource_revision with given id" do
      resource_revision = resource_revision_fixture()
      assert Resources.get_resource_revision!(resource_revision.id) == resource_revision
    end

    test "create_resource_revision/1 with valid data creates a resource_revision" do
      assert {:ok, %ResourceRevision{} = resource_revision} = Resources.create_resource_revision(@valid_attrs)
      assert resource_revision.children == %{}
      assert resource_revision.content == %{}
      assert resource_revision.deleted == true
      assert resource_revision.slug == "some slug"
      assert resource_revision.title == "some title"
    end

    test "create_resource_revision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Resources.create_resource_revision(@invalid_attrs)
    end

    test "update_resource_revision/2 with valid data updates the resource_revision" do
      resource_revision = resource_revision_fixture()
      assert {:ok, %ResourceRevision{} = resource_revision} = Resources.update_resource_revision(resource_revision, @update_attrs)
      assert resource_revision.children == %{}
      assert resource_revision.content == %{}
      assert resource_revision.deleted == false
      assert resource_revision.slug == "some updated slug"
      assert resource_revision.title == "some updated title"
    end

    test "update_resource_revision/2 with invalid data returns error changeset" do
      resource_revision = resource_revision_fixture()
      assert {:error, %Ecto.Changeset{}} = Resources.update_resource_revision(resource_revision, @invalid_attrs)
      assert resource_revision == Resources.get_resource_revision!(resource_revision.id)
    end

    test "delete_resource_revision/1 deletes the resource_revision" do
      resource_revision = resource_revision_fixture()
      assert {:ok, %ResourceRevision{}} = Resources.delete_resource_revision(resource_revision)
      assert_raise Ecto.NoResultsError, fn -> Resources.get_resource_revision!(resource_revision.id) end
    end

    test "change_resource_revision/1 returns a resource_revision changeset" do
      resource_revision = resource_revision_fixture()
      assert %Ecto.Changeset{} = Resources.change_resource_revision(resource_revision)
    end
  end
end
