defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Accounts.{SystemRole, Institution, Author}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing
  alias Oli.Publishing.{Publication, ResourceMapping, ActivityMapping, ObjectiveMapping}
  alias Oli.Authoring.Resources
  alias Oli.Authoring.Resources.{Resource, ResourceFamily, ResourceRevision}
  alias Oli.Authoring.Activities.{Activity, ActivityFamily, ActivityRevision, Registration}
  alias Oli.Authoring.Learning.{Objective, ObjectiveFamily, ObjectiveRevision}

  describe "publications" do

    @valid_attrs %{description: "some description", published: true, project: 0}
    @update_attrs %{description: "some updated description", published: false, project: 0}
    @invalid_attrs %{description: nil, published: nil, root_resource_id: nil}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "slug"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "slug", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :project_id, project.id)

      {:ok, %{publication: publication, project: project, family: family, valid_attrs: valid_attrs, resource: resource}}
    end

    test "get_published_objectives/1 returns the objective revisions", _ do

      %{publication: publication} = Oli.Seeder.base_project_with_resource()
        |> Oli.Seeder.add_objective("one")
        |> Oli.Seeder.add_objective("two")
        |> Oli.Seeder.add_objective("three")

      [first | rest ] = Publishing.get_published_objectives(publication.id)
      assert length(rest) == 2
      assert first.slug == "one"
      assert first.title == "one"

    end


    test "get_unpublished_publications/2 returns the correct publication", %{publication: publication, family: family, project: project, resource: resource} do

      # add a few more published publications
      {:ok, _another} = Publication.changeset(%Publication{}, %{description: "description", published: true, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, _another} = Publication.changeset(%Publication{}, %{description: "description", published: true, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert

      # and another project with an unpublished publication
      {:ok, project2} = Project.changeset(%Project{}, %{description: "description", slug: "title", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication2} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project2.id}) |> Repo.insert

      assert Publishing.get_unpublished_publication("slug", 1).id == publication.id
      assert Publishing.get_unpublished_publication("title", 1).id == publication2.id
    end

    test "get_publication!/1 returns the publication with given id", %{publication: publication} do
      assert Publishing.get_publication!(publication.id) == publication
    end

    test "create_publication/1 with valid data creates a publication", %{valid_attrs: valid_attrs, resource: resource} do
      assert {:ok, %Publication{} = publication} = Publishing.create_publication(Map.put(valid_attrs, :root_resource_id, resource.id))
      assert publication.description == "some description"
      assert publication.published == true
      assert Repo.preload(publication, [:root_resource]).root_resource == resource
    end

    test "create_publication/1 with invalid data returns error changeset", %{publication: _publication} do
      assert {:error, %Ecto.Changeset{}} = Publishing.create_publication(@invalid_attrs)
    end

  end

  describe "resource_mappings" do

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
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

    test "get_resource_mapping!/1 returns the resource_mapping with given id", %{resource_mapping: resource_mapping} do
      assert Publishing.get_resource_mapping!(resource_mapping.id) == resource_mapping
    end

    test "get_resource_mapping!/2 returns the resource_mapping with given publication and resource", %{resource_mapping: resource_mapping} do
      assert Publishing.get_resource_mapping!(resource_mapping.publication_id, resource_mapping.resource_id) == resource_mapping
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

  end

  describe "activity_mappings" do

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      {:ok, activity_family} = ActivityFamily.changeset(%ActivityFamily{}, %{}) |> Repo.insert
      {:ok, activity} = Activity.changeset(%Activity{}, %{project_id: project.id, family_id: activity_family.id}) |> Repo.insert
      {:ok, activity_type} = Registration.changeset(%Registration{}, %{authoring_script: "1", delivery_script: "2", description: "d", element_name: "n", icon: "i", title: "t"}) |> Repo.insert
      {:ok, revision} = ActivityRevision.changeset(%ActivityRevision{}, %{author_id: author.id, activity_id: activity.id, activity_type_id: activity_type.id, content: %{}, objectives: [], deleted: true, slug: "some slug"}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :revision_id, revision.id)
        |> Map.put(:publication_id, publication.id)
        |> Map.put(:activity_id, activity.id)

      {:ok, activity_mapping} = Publishing.create_activity_mapping(valid_attrs)

      {:ok, %{activity_mapping: activity_mapping, valid_attrs: valid_attrs}}
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

  end

  describe "objective_mappings" do

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
      {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, _institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert
      {:ok, objective_family} = ObjectiveFamily.changeset(%ObjectiveFamily{}, %{}) |> Repo.insert
      {:ok, objective} = Objective.changeset(%Objective{}, %{family_id: objective_family.id, project_id: project.id}) |> Repo.insert
      {:ok, objective_revision} = ObjectiveRevision.changeset(%ObjectiveRevision{}, %{title: "some title", children: [], deleted: false, objective_id: objective.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :objective_id, objective.id)
        |> Map.put(:revision_id, objective_revision.id)
        |> Map.put(:publication_id, publication.id)

      {:ok, objective_mapping} = valid_attrs |> Publishing.create_objective_mapping()

      {:ok, %{objective_mapping: objective_mapping, valid_attrs: valid_attrs}}
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

    test "change_objective_mapping/1 returns a objective_mapping changeset", %{objective_mapping: objective_mapping} do
      assert %Ecto.Changeset{} = Publishing.change_objective_mapping(objective_mapping)
    end
  end
end
