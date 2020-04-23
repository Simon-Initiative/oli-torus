defmodule Oli.Seeder do

  alias Oli.Publishing2, as: Publishing
  alias Oli.Repo
  alias Oli.Accounts.{SystemRole, ProjectRole, Institution, Author}
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Authoring.Learning.{Objective, ObjectiveFamily, ObjectiveRevision}
  alias Oli.Authoring.Resources
  alias Oli.Authoring.Resources.{Resource, ResourceFamily, ResourceRevision}
  alias Oli.Publishing.Publication


  def base_project_with_resource2() do

    {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
    {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
    {:ok, author2} = Author.changeset(%Author{}, %{email: "test2@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert

    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert
    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author2.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert

    {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

    # A single container resource with a mapped revision
    {:ok, container_resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: container_resource.id}) |> Repo.insert
    {:ok, container_revision} = Oli.Resources.create_revision(%{author_id: author.id, objectives: %{}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"), children: [], content: %{}, deleted: false, slug: "some_title", title: "some title", resource_id: container_resource.id})

    {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: container_resource.id, project_id: project.id}) |> Repo.insert

    publish_resource(publication, container_resource, container_revision)

    %{resource: page1, revision: revision1} = create_page("Page one", publication, project, author)
    %{resource: page2, revision: revision2} = create_page("Page two", publication, project, author)
    container_revision = attach_pages_to([page1, page2], container_resource, container_revision, publication)

    Map.put(%{}, :family, family)
      |> Map.put(:project, project)
      |> Map.put(:author, author)
      |> Map.put(:author2, author2)
      |> Map.put(:institution, institution)
      |> Map.put(:publication, publication)
      |> Map.put(:container_resource, container_resource)
      |> Map.put(:container_revision, container_revision)
      |> Map.put(:page1, page1)
      |> Map.put(:page2, page2)
      |> Map.put(:revision1, revision1)
      |> Map.put(:revision2, revision2)

  end

  defp publish_resource(publication, resource, revision) do
    Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource.id, revision_id: revision.id})
  end

  def create_page(title, publication, project, author) do

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert
    {:ok, revision} = Oli.Resources.create_revision(%{author_id: author.id, objectives: %{}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"), children: [], content: %{ "model" => []}, deleted: false, title: title, resource_id: resource.id})
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def attach_pages_to(resources, container, container_revision, publication) do

    children = Enum.map(resources, fn r -> r.id end)
    {:ok, updated} = Oli.Resources.update_revision(container_revision, %{children: children})

    Publishing.get_resource_mapping!(publication.id, container.id)
      |> Publishing.update_resource_mapping(%{revision_id: updated.id})

    updated
  end

  def base_project_with_resource() do

    {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
    {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert

    {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

    # A single container resource with a mapped revision
    {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
    {:ok, container_resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert
    {:ok, container_revision} = ResourceRevision.changeset(%ResourceRevision{}, %{author_id: author.id, objectives: [], resource_type_id: Resources.resource_type().container.id, children: [], content: [], deleted: false, slug: "some_title", title: "some title", resource_id: container_resource.id}) |> Repo.insert

    # Apply the container resource as the publication root resource
    {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resource_id: container_resource.id, project_id: project.id}) |> Repo.insert
    {:ok, _mapping} = Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: container_resource.id, revision_id: container_revision.id})

    # Add two children "page" resources to the publication
    {:ok, resource_family2} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
    {:ok, resource2} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family2.id}) |> Repo.insert
    {:ok, revision2} = ResourceRevision.changeset(%ResourceRevision{}, %{author_id: author.id, objectives: [], resource_type_id: Resources.resource_type().unscored_page.id, children: [], content: [], deleted: false, slug: "unscored_page_1", title: "Unscored Page 1", resource_id: resource2.id}) |> Repo.insert
    {:ok, mapping2} = Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource2.id, revision_id: revision2.id})

    {:ok, resource_family3} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
    {:ok, resource3} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family3.id}) |> Repo.insert
    {:ok, revision3} = ResourceRevision.changeset(%ResourceRevision{}, %{author_id: author.id, objectives: [], resource_type_id: Resources.resource_type().unscored_page.id, children: [], content: [], deleted: false, slug: "unscored_page_2", title: "Unscored Page 2", resource_id: resource3.id}) |> Repo.insert
    {:ok, _mapping3} = Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource3.id, revision_id: revision3.id})

    # add resource 2 and 3 as children to the container and update mappings
    Resources.update_resource_revision(
      Oli.Authoring.Editing.ResourceEditor.create_new_revision(
            container_revision,
            publication,
            container_resource,
            author.id),
      %{children: [resource2.id, resource3.id]})

    Map.put(%{}, :family, family)
      |> Map.put(:project, project)
      |> Map.put(:publication, publication)
      |> Map.put(:author, author)
      |> Map.put(:institution, institution)
      |> Map.put(:resource_family, resource_family)
      |> Map.put(:resource, resource2)
      |> Map.put(:revision, revision2)
      |> Map.put(:mapping, mapping2)
  end

  def add_objective(%{ project: project, publication: publication, author: author} = map, title) do

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert
    {:ok, revision} = Oli.Resources.create_revision(%{author_id: author.id, objectives: %{}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"), children: [], content: %{}, deleted: false, title: title, resource_id: resource.id})
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    map
  end

  def add_author(%{ project: project} = map, author, atom) do
    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert
    Map.put(map, atom, author)
  end

end
