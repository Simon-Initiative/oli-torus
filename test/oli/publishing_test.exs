defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Accounts.{SystemRole, Institution, Author}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing
  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Resources.Resource
  alias Oli.Resources.ResourceFamily
  alias Oli.Resources.ResourceRevision
  alias Oli.Activities.Activity
  alias Oli.Activities.ActivityFamily
  alias Oli.Activities.ActivityRevision
  alias Oli.Activities.Registration
  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveFamily
  alias Oli.Learning.ObjectiveRevision
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
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


    test "get_unpublished_publication_by_slug!/1 returns the correct publication", %{publication: publication, family: family, project: project, resource: resource} do

      # add a few more published publications
      {:ok, _another} = Publication.changeset(%Publication{}, %{description: "description", published: true, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert
      {:ok, _another} = Publication.changeset(%Publication{}, %{description: "description", published: true, root_resource_id: resource.id, project_id: project.id}) |> Repo.insert

      # and another project with an unpublished publication
      {:ok, project2} = Project.changeset(%Project{}, %{description: "description", slug: "title", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication2} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: resource.id, project_id: project2.id}) |> Repo.insert

      assert Publishing.get_unpublished_publication_by_slug!("slug").id == publication.id
      assert Publishing.get_unpublished_publication_by_slug!("title").id == publication2.id
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
    # @update_attrs %{}
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
      {:ok, activity_type} = Registration.changeset(%Registration{}, %{slug: "slug", authoring_script: "1", delivery_script: "2", description: "d", authoring_element: "n", delivery_element: "n", icon: "i", title: "t"}) |> Repo.insert
      {:ok, revision} = ActivityRevision.changeset(%ActivityRevision{}, %{author_id: author.id, activity_id: activity.id, activity_type_id: activity_type.id, content: %{}, objectives: %{}, deleted: true, slug: "some slug"}) |> Repo.insert

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
    # @update_attrs %{}
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

  describe "project publishing" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "publish_project/1 publishes the active unpublished publication and creates a new working unpublished publication for a project", %{publication: publication, project: project} do
      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # original publication should now be published
      assert published.id == publication.id
      assert published.published == true
    end

    test "publish_project/1 creates a new working unpublished publication for a project",
      %{publication: publication, project: project} do

      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # the unpublished publication for the project should now be a new different publication
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_publication.id != publication.id

      # mappings should be retained in the original published publication
      original_resource_mappings = Publishing.get_resource_mappings_by_publication(publication.id)
      original_activity_mappings = Publishing.get_resource_mappings_by_publication(publication.id)
      original_objective_mappings = Publishing.get_resource_mappings_by_publication(publication.id)
      published_resource_mappings = Publishing.get_resource_mappings_by_publication(published.id)
      published_activity_mappings = Publishing.get_resource_mappings_by_publication(published.id)
      published_objective_mappings = Publishing.get_resource_mappings_by_publication(published.id)
      assert original_resource_mappings == published_resource_mappings
      assert original_activity_mappings == published_activity_mappings
      assert original_objective_mappings == published_objective_mappings

      # mappings should now be replaced with new mappings in the new publication
      assert original_resource_mappings != Publishing.get_resource_mappings_by_publication(new_publication.id)
      assert original_activity_mappings != Publishing.get_activity_mappings_by_publication(new_publication.id)
      assert original_objective_mappings != Publishing.get_objective_mappings_by_publication(new_publication.id)
    end

    test "publish_project/1 publishes all currently locked resources and any new edits to the locked resource result in creation of a new revision",
      %{publication: publication, project: project, author: author, mapping: mapping, revision: revision} do

      # lock the resource
      Publishing.update_resource_mapping(mapping, %{lock_updated_at: now(), locked_by_id: author.id})

      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # publication should succeed even if a resource is "locked"
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_publication.id != publication.id

      # further edits to the locked resource should occur in a new revision
      content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
      {:ok, updated_revision} = ResourceEditor.edit(project.slug, revision.slug, author.email, %{ content: content })
      assert revision.id != updated_revision.id

      # further edits should not be present in published resource
      resource_mapping = Publishing.get_resource_mapping!(published.id, revision.resource_id)
      old_revision = Resources.get_resource_revision!(resource_mapping.revision_id)
      assert old_revision.content == revision.content
    end

    test "update_all_section_publications/2 updates all existing sections using the project to the latest publication",
      %{project: project} do
      institution = institution_fixture()

      {:ok, original_publication} = Publishing.publish_project(project)

      {:ok, %Section{id: section_id}} = Sections.create_section(%{
        time_zone: "US/Central",
        title: "title",
        context_id: "some-context-id",
        institution_id: institution.id,
        project_id: project.id,
        publication_id: original_publication.id,
      })

      assert [%Section{id: ^section_id}] = Sections.get_sections_by_publication(original_publication)

      {:ok, original_publication} = Publishing.publish_project(project)

      # update all sections to use the new publication
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      Publishing.update_all_section_publications(project, new_publication)

      # section associated with new publication...
      assert [%Section{id: ^section_id}] = Sections.get_sections_by_publication(new_publication)

      # ...and removed from the old one
      assert [] = Sections.get_sections_by_publication(original_publication)
    end

    test "diff_publications/2 returns the changes between 2 publications",
      %{project: project, author: author, revision: revision} do
        # create a few more resources
        {:ok, %{revision: r2_revision}} = Resources.create_project_resource(%{
          objectives: [],
          children: [],
          content: [],
          title: "resource 1",
        }, Resources.resource_type.unscored_page, author, project)
        {:ok, %{revision: r3_revision}} = Resources.create_project_resource(%{
          objectives: [],
          children: [],
          content: [],
          title: "resource 2",
        }, Resources.resource_type.unscored_page, author, project)

        # create first publication
        {:ok, %Publication{} = p1} = Publishing.publish_project(project)

        # make some edits
        content = [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]
        {:ok, _updated_revision} = ResourceEditor.edit(project.slug, revision.slug, author.email, %{content: content})

        # add another resource
        {:ok, %{revision: r4_revision}} = Resources.create_project_resource(%{
          objectives: [],
          children: [],
          content: [],
          title: "resource 3",
        }, Resources.resource_type.unscored_page, author, project)

        # delete a resource
        {:ok, _updated_revision} = ResourceEditor.edit(project.slug, r3_revision.slug, author.email, %{deleted: true})

        # get the active publication as the second publication
        p2 = Publishing.get_unpublished_publication_by_slug!(project.slug)

        # generate diff
        diff = Publishing.diff_publications(p1, p2)

        assert Map.keys(diff) |> Enum.count == 4
        assert {:changed, _} = diff[revision.resource_id]
        assert {:identical, _} = diff[r2_revision.resource_id]
        assert {:deleted, _} = diff[r3_revision.resource_id]
        assert {:added, _} = diff[r4_revision.resource_id]
    end

  end
end
