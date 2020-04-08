defmodule Oli.Seeder do

  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Accounts.SystemRole
  alias Oli.Accounts.ProjectRole
  alias Oli.Accounts.Institution
  alias Oli.Accounts.Author
  alias Oli.Accounts.AuthorProject
  alias Oli.Course.Project
  alias Oli.Course.Family
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Resources.Resource
  alias Oli.Resources.ResourceFamily
  alias Oli.Resources.ResourceRevision

  def base_project_with_resource() do

    {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
    {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
    {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: false, root_resources: [], project_id: project.id}) |> Repo.insert
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert

    {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

    {:ok, resource_family} = ResourceFamily.changeset(%ResourceFamily{}, %{}) |> Repo.insert
    {:ok, resource} = Resource.changeset(%Resource{}, %{project_id: project.id, family_id: resource_family.id}) |> Repo.insert

    resource_type = Resources.list_resource_types() |> hd

    {:ok, revision} = ResourceRevision.changeset(%ResourceRevision{}, %{author_id: author.id, objectives: [], resource_type_id: resource_type.id, children: [], content: [], deleted: true, slug: "some_title", title: "some title", resource_id: resource.id}) |> Repo.insert

    {:ok, mapping} = Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource.id, revision_id: revision.id})



    Map.put(%{}, :family, family)
      |> Map.put(:project, project)
      |> Map.put(:publication, publication)
      |> Map.put(:author, author)
      |> Map.put(:institution, institution)
      |> Map.put(:resource_family, resource_family)
      |> Map.put(:resource, resource)
      |> Map.put(:resource_type, resource_type)
      |> Map.put(:revision, revision)
      |> Map.put(:mapping, mapping)
  end

end
