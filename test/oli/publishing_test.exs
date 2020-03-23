defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Publishing

  describe "publications" do
    alias Oli.Publishing.Publication

    @valid_attrs %{description: "some description", published: true, root_resources: %{}}
    @update_attrs %{description: "some updated description", published: false, root_resources: %{}}
    @invalid_attrs %{description: nil, published: nil, root_resources: nil}

    def publication_fixture(attrs \\ %{}) do
      {:ok, publication} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Publishing.create_publication()

      publication
    end

    test "list_publications/0 returns all publications" do
      publication = publication_fixture()
      assert Publishing.list_publications() == [publication]
    end

    test "get_publication!/1 returns the publication with given id" do
      publication = publication_fixture()
      assert Publishing.get_publication!(publication.id) == publication
    end

    test "create_publication/1 with valid data creates a publication" do
      assert {:ok, %Publication{} = publication} = Publishing.create_publication(@valid_attrs)
      assert publication.description == "some description"
      assert publication.published == true
      assert publication.root_resources == %{}
    end

    test "create_publication/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_publication(@invalid_attrs)
    end

    test "update_publication/2 with valid data updates the publication" do
      publication = publication_fixture()
      assert {:ok, %Publication{} = publication} = Publishing.update_publication(publication, @update_attrs)
      assert publication.description == "some updated description"
      assert publication.published == false
      assert publication.root_resources == %{}
    end

    test "update_publication/2 with invalid data returns error changeset" do
      publication = publication_fixture()
      assert {:error, %Ecto.Changeset{}} = Publishing.update_publication(publication, @invalid_attrs)
      assert publication == Publishing.get_publication!(publication.id)
    end

    test "delete_publication/1 deletes the publication" do
      publication = publication_fixture()
      assert {:ok, %Publication{}} = Publishing.delete_publication(publication)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_publication!(publication.id) end
    end

    test "change_publication/1 returns a publication changeset" do
      publication = publication_fixture()
      assert %Ecto.Changeset{} = Publishing.change_publication(publication)
    end
  end

  describe "resource_mappings" do
    alias Oli.Publishing.ResourceMapping

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def resource_mapping_fixture(attrs \\ %{}) do
      {:ok, resource_mapping} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Publishing.create_resource_mapping()

      resource_mapping
    end

    test "list_resource_mappings/0 returns all resource_mappings" do
      resource_mapping = resource_mapping_fixture()
      assert Publishing.list_resource_mappings() == [resource_mapping]
    end

    test "get_resource_mapping!/1 returns the resource_mapping with given id" do
      resource_mapping = resource_mapping_fixture()
      assert Publishing.get_resource_mapping!(resource_mapping.id) == resource_mapping
    end

    test "create_resource_mapping/1 with valid data creates a resource_mapping" do
      assert {:ok, %ResourceMapping{} = resource_mapping} = Publishing.create_resource_mapping(@valid_attrs)
    end

    test "create_resource_mapping/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_resource_mapping(@invalid_attrs)
    end

    test "update_resource_mapping/2 with valid data updates the resource_mapping" do
      resource_mapping = resource_mapping_fixture()
      assert {:ok, %ResourceMapping{} = resource_mapping} = Publishing.update_resource_mapping(resource_mapping, @update_attrs)
    end

    test "update_resource_mapping/2 with invalid data returns error changeset" do
      resource_mapping = resource_mapping_fixture()
      assert {:error, %Ecto.Changeset{}} = Publishing.update_resource_mapping(resource_mapping, @invalid_attrs)
      assert resource_mapping == Publishing.get_resource_mapping!(resource_mapping.id)
    end

    test "delete_resource_mapping/1 deletes the resource_mapping" do
      resource_mapping = resource_mapping_fixture()
      assert {:ok, %ResourceMapping{}} = Publishing.delete_resource_mapping(resource_mapping)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_resource_mapping!(resource_mapping.id) end
    end

    test "change_resource_mapping/1 returns a resource_mapping changeset" do
      resource_mapping = resource_mapping_fixture()
      assert %Ecto.Changeset{} = Publishing.change_resource_mapping(resource_mapping)
    end
  end

  describe "activity_mappings" do
    alias Oli.Publishing.ActivityMapping

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def activity_mapping_fixture(attrs \\ %{}) do
      {:ok, activity_mapping} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Publishing.create_activity_mapping()

      activity_mapping
    end

    test "list_activity_mappings/0 returns all activity_mappings" do
      activity_mapping = activity_mapping_fixture()
      assert Publishing.list_activity_mappings() == [activity_mapping]
    end

    test "get_activity_mapping!/1 returns the activity_mapping with given id" do
      activity_mapping = activity_mapping_fixture()
      assert Publishing.get_activity_mapping!(activity_mapping.id) == activity_mapping
    end

    test "create_activity_mapping/1 with valid data creates a activity_mapping" do
      assert {:ok, %ActivityMapping{} = activity_mapping} = Publishing.create_activity_mapping(@valid_attrs)
    end

    test "create_activity_mapping/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_activity_mapping(@invalid_attrs)
    end

    test "update_activity_mapping/2 with valid data updates the activity_mapping" do
      activity_mapping = activity_mapping_fixture()
      assert {:ok, %ActivityMapping{} = activity_mapping} = Publishing.update_activity_mapping(activity_mapping, @update_attrs)
    end

    test "update_activity_mapping/2 with invalid data returns error changeset" do
      activity_mapping = activity_mapping_fixture()
      assert {:error, %Ecto.Changeset{}} = Publishing.update_activity_mapping(activity_mapping, @invalid_attrs)
      assert activity_mapping == Publishing.get_activity_mapping!(activity_mapping.id)
    end

    test "delete_activity_mapping/1 deletes the activity_mapping" do
      activity_mapping = activity_mapping_fixture()
      assert {:ok, %ActivityMapping{}} = Publishing.delete_activity_mapping(activity_mapping)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_activity_mapping!(activity_mapping.id) end
    end

    test "change_activity_mapping/1 returns a activity_mapping changeset" do
      activity_mapping = activity_mapping_fixture()
      assert %Ecto.Changeset{} = Publishing.change_activity_mapping(activity_mapping)
    end
  end
end
