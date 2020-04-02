defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Publishing

  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Course.Project
  alias Oli.Course.Family
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Resources.Resource
  alias Oli.Resources.ResourceFamily
  alias Oli.Resources.ResourceRevision
  alias Oli.Activities.Activity
  alias Oli.Activities.ActivityRevision
  alias Oli.Activities.Registration
  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveRevision

  describe "publications" do
    alias Oli.Publishing.Publication

    @valid_attrs %{description: "some description", published: true, root_resources: [], project: 0}
    @update_attrs %{description: "some updated description", published: false, root_resources: [], project: 0}
    @invalid_attrs %{description: nil, published: nil, root_resources: nil}

    def publication_fixture(attrs \\ %{}) do
      {:ok, publication} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Publishing.create_publication()

      publication
    end


    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{publication: publication, valid_attrs: valid_attrs}}
    end


    test "list_publications/0 returns all publications", %{publication: publication} do
      assert Publishing.list_publications() == [publication]
    end

    test "get_publication!/1 returns the publication with given id", %{publication: publication} do
      assert Publishing.get_publication!(publication.id) == publication
    end

    test "create_publication/1 with valid data creates a publication", %{valid_attrs: valid_attrs} do
      assert {:ok, %Publication{} = publication} = Publishing.create_publication(valid_attrs)
      assert publication.description == "some description"
      assert publication.published == false
      assert publication.root_resources == []
    end

    test "create_publication/1 with invalid data returns error changeset", %{publication: _publication} do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_publication(@invalid_attrs)
    end

    test "update_publication/2 with valid data updates the publication", %{publication: publication} do
      assert {:ok, %Publication{} = publication} = Publishing.update_publication(publication, @update_attrs)
      assert publication.description == "some updated description"
      assert publication.published == false
      assert publication.root_resources == []
    end

    test "update_publication/2 with invalid data returns error changeset", %{publication: publication} do
      assert {:error, %Ecto.Changeset{}} = Publishing.update_publication(publication, @invalid_attrs)
      assert publication == Publishing.get_publication!(publication.id)
    end

    test "delete_publication/1 deletes the publication", %{publication: publication} do
      assert {:ok, %Publication{}} = Publishing.delete_publication(publication)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_publication!(publication.id) end
    end

    test "change_publication/1 returns a publication changeset", %{publication: publication} do
      assert %Ecto.Changeset{} = Publishing.change_publication(publication)
    end
  end

  describe "resource_mappings" do
    alias Oli.Publishing.ResourceMapping

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert

      resource_type = Resources.list_resource_types() |> hd

      {:ok, revision} = ResourceRevision.changeset(%ResourceRevision{}, %{author_id: author.id, objectives: [], resource_type_id: resource_type.id, children: [], content: [], deleted: true, slug: "some slug", title: "some title", resource_id: resource.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :publication_id, publication.id)
        |> Map.put(:resource_id, resource.id)
        |> Map.put(:revision_id, revision.id)

      {:ok, resource_mapping} = valid_attrs |> Publishing.create_resource_mapping()

      {:ok, %{resource_mapping: resource_mapping, valid_attrs: valid_attrs}}
    end


    test "list_resource_mappings/0 returns all resource_mappings", %{resource_mapping: resource_mapping} do
      assert Publishing.list_resource_mappings() == [resource_mapping]
    end

    test "get_resource_mapping!/1 returns the resource_mapping with given id", %{resource_mapping: resource_mapping} do
      assert Publishing.get_resource_mapping!(resource_mapping.id) == resource_mapping
    end

    test "create_resource_mapping/1 with valid data creates a resource_mapping", %{valid_attrs: valid_attrs} do
      assert {:ok, %ResourceMapping{} = resource_mapping} = Publishing.create_resource_mapping(valid_attrs)
    end

    test "create_resource_mapping/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_resource_mapping(@invalid_attrs)
    end

    test "update_resource_mapping/2 with valid data updates the resource_mapping", %{resource_mapping: resource_mapping} do
      assert {:ok, %ResourceMapping{} = resource_mapping} = Publishing.update_resource_mapping(resource_mapping, @update_attrs)
    end

    test "update_resource_mapping/2 with invalid data returns error changeset", %{resource_mapping: resource_mapping} do
      assert resource_mapping == Publishing.get_resource_mapping!(resource_mapping.id)
    end

    test "delete_resource_mapping/1 deletes the resource_mapping", %{resource_mapping: resource_mapping} do
      assert {:ok, %ResourceMapping{}} = Publishing.delete_resource_mapping(resource_mapping)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_resource_mapping!(resource_mapping.id) end
    end

    test "change_resource_mapping/1 returns a resource_mapping changeset", %{resource_mapping: resource_mapping} do
      assert %Ecto.Changeset{} = Publishing.change_resource_mapping(resource_mapping)
    end
  end

  describe "activity_mappings" do
    alias Oli.Publishing.ActivityMapping

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, activity} = Activity.changeset(%Activity{}, %{slug: "slug", project_id: project.id}) |> Repo.insert
      {:ok, activity_type} = Registration.changeset(%Registration{}, %{authoring_script: "1", delivery_script: "2", description: "d", element_name: "n", icon: "i", title: "t"}) |> Repo.insert
      {:ok, revision} = ActivityRevision.changeset(%ActivityRevision{}, %{author_id: author.id, activity_id: activity.id, activity_type_id: activity_type.id, content: %{}, objectives: [], deleted: true, slug: "some slug"}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :revision_id, revision.id)
        |> Map.put(:publication_id, publication.id)
        |> Map.put(:activity_id, activity.id)

      {:ok, activity_mapping} = Publishing.create_activity_mapping(valid_attrs)

      {:ok, %{activity_mapping: activity_mapping, valid_attrs: valid_attrs}}
    end

    test "list_activity_mappings/0 returns all activity_mappings", %{activity_mapping: activity_mapping} do
      assert Publishing.list_activity_mappings() == [activity_mapping]
    end

    test "get_activity_mapping!/1 returns the activity_mapping with given id", %{activity_mapping: activity_mapping} do
      assert Publishing.get_activity_mapping!(activity_mapping.id) == activity_mapping
    end

    test "create_activity_mapping/1 with valid data creates a activity_mapping", %{valid_attrs: valid_attrs} do
      assert {:ok, %ActivityMapping{} = activity_mapping} = Publishing.create_activity_mapping(valid_attrs)
    end

    test "create_activity_mapping/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_activity_mapping(@invalid_attrs)
    end

    test "update_activity_mapping/2 with valid data updates the activity_mapping", %{activity_mapping: activity_mapping} do
      assert {:ok, %ActivityMapping{} = activity_mapping} = Publishing.update_activity_mapping(activity_mapping, @update_attrs)
    end

    test "update_activity_mapping/2 with invalid data returns error changeset", %{activity_mapping: activity_mapping} do
      assert activity_mapping == Publishing.get_activity_mapping!(activity_mapping.id)
    end

    test "delete_activity_mapping/1 deletes the activity_mapping", %{activity_mapping: activity_mapping} do
      assert {:ok, %ActivityMapping{}} = Publishing.delete_activity_mapping(activity_mapping)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_activity_mapping!(activity_mapping.id) end
    end

    test "change_activity_mapping/1 returns a activity_mapping changeset", %{activity_mapping: activity_mapping} do
      assert %Ecto.Changeset{} = Publishing.change_activity_mapping(activity_mapping)
    end
  end

  describe "objective_mappings" do
    alias Oli.Publishing.ObjectiveMapping

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, objective} = Objective.changeset(%Objective{}, %{slug: "slug", project_id: project.id}) |> Repo.insert
      {:ok, objective_revision} = ObjectiveRevision.changeset(%ObjectiveRevision{}, %{title: "some title", children: [], deleted: false, objective_id: objective.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :objective_id, objective.id)
        |> Map.put(:revision_id, objective_revision.id)
        |> Map.put(:publication_id, publication.id)

      {:ok, objective_mapping} = valid_attrs |> Publishing.create_objective_mapping()

      {:ok, %{objective_mapping: objective_mapping, valid_attrs: valid_attrs}}
    end

    test "list_objective_mappings/0 returns all objective_mappings", %{objective_mapping: objective_mapping} do
      assert Publishing.list_objective_mappings() == [objective_mapping]
    end

    test "get_objective_mapping!/1 returns the objective_mapping with given id", %{objective_mapping: objective_mapping} do
      assert Publishing.get_objective_mapping!(objective_mapping.id) == objective_mapping
    end

    test "create_objective_mapping/1 with valid data creates a objective_mapping", %{valid_attrs: valid_attrs} do
      assert {:ok, %ObjectiveMapping{} = objective_mapping} = Publishing.create_objective_mapping(valid_attrs)
    end

    test "create_objective_mapping/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_objective_mapping(@invalid_attrs)
    end

    test "update_objective_mapping/2 with valid data updates the objective_mapping", %{objective_mapping: objective_mapping} do
      assert {:ok, %ObjectiveMapping{} = objective_mapping} = Publishing.update_objective_mapping(objective_mapping, @update_attrs)
    end

    test "update_objective_mapping/2 with invalid data returns error changeset", %{objective_mapping: objective_mapping} do
      assert objective_mapping == Publishing.get_objective_mapping!(objective_mapping.id)
    end

    test "delete_objective_mapping/1 deletes the objective_mapping", %{objective_mapping: objective_mapping} do
      assert {:ok, %ObjectiveMapping{}} = Publishing.delete_objective_mapping(objective_mapping)
      assert_raise Ecto.NoResultsError, fn -> Publishing.get_objective_mapping!(objective_mapping.id) end
    end

    test "change_objective_mapping/1 returns a objective_mapping changeset", %{objective_mapping: objective_mapping} do
      assert %Ecto.Changeset{} = Publishing.change_objective_mapping(objective_mapping)
    end
  end
end
