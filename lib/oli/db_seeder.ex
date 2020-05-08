defmodule Oli.Seeder do

  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Accounts.{SystemRole, ProjectRole, Institution, Author}
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.{ResourceAccess}
  alias Oli.Activities.Model.Part
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing.Publication
  alias Oli.Accounts.LtiToolConsumer
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

  def base_project_with_resource2() do

    {:ok, family} = Family.changeset(%Family{}, %{description: "description", title: "title"}) |> Repo.insert
    {:ok, project} = Project.changeset(%Project{}, %{description: "description", title: "title", version: "1", family_id: family.id}) |> Repo.insert
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
      |> add_lti_consumer(%{}, :lti_consumer)

  end

  def create_section(map) do

    params = %{end_date: ~D[2010-04-17],
      open_and_free: true,
      registration_open: true,
      start_date: ~D[2010-04-17],
      time_zone: "some time_zone",
      title: "some title",
      context_id: "context_id",
      project_id: map.project.id,
      publication_id: map.publication.id,
      institution_id: map.institution.id
    }

    {:ok, section} =
      Section.changeset(%Section{}, params)
      |> Repo.insert()

    Map.put(map, :section, section)

  end

  def another_project(author, institution) do

    {:ok, family} = Family.changeset(%Family{}, %{description: "description", title: "title"}) |> Repo.insert
    {:ok, project} = Project.changeset(%Project{}, %{description: "description", title: "title", version: "1", family_id: family.id}) |> Repo.insert

    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert

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
      |> Map.put(:institution, institution)
      |> Map.put(:publication, publication)
      |> Map.put(:container_resource, container_resource)
      |> Map.put(:container_revision, container_revision)
      |> Map.put(:page1, page1)
      |> Map.put(:page2, page2)
      |> Map.put(:revision1, revision1)
      |> Map.put(:revision2, revision2)
      |> add_lti_consumer(%{}, :lti_consumer)

  end

  def create_resource_attempt(map, attrs, user_tag, resource_tag, revision_tag, tag \\ nil) do

    user = Map.get(map, user_tag)
    resource = Map.get(map, resource_tag)
    revision = Map.get(map, revision_tag)
    section = map.section

    %ResourceAccess{id: id} = Attempts.track_access(resource.id, section.id, user.id)

    attrs = Map.merge(attrs, %{
      resource_access_id: id,
      revision_id: revision.id
    })

    {:ok, attempt} = Attempts.create_resource_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  def create_part_attempt(map, attrs, %Part{} = part, attempt_tag, tag \\ nil) do

    resource_attempt = Map.get(map, attempt_tag)

    attrs = Map.merge(attrs, %{
      resource_attempt_id: resource_attempt.id,
      part_id: part.id
    })

    {:ok, attempt} = Attempts.create_part_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  defp publish_resource(publication, resource, revision) do
    Publishing.create_resource_mapping(%{ publication_id: publication.id, resource_id: resource.id, revision_id: revision.id})
  end

  def create_page(title, publication, project, author) do

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert
    {:ok, revision} = Oli.Resources.create_revision(%{author_id: author.id, objectives: %{ "attached" => []}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"), children: [], content: %{ "model" => []}, deleted: false, title: title, resource_id: resource.id})
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def add_user(map, attrs, tag \\ nil) do

    consumer = map.lti_consumer
    institution = map.institution

    params =
      attrs
      |> Enum.into(%{
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        user_id: "2u9dfh7979hfd",
        user_image: "none",
        roles: "none",
        lti_tool_consumer_id: consumer.id,
        institution_id: institution.id
      })

    {:ok, user} =
      User.changeset(%User{}, params)
      |> Repo.insert()

    case tag do
      nil -> map
      t -> Map.put(map, t, user)
    end
  end

  def add_lti_consumer(map, attrs, tag \\ nil) do
    params =
      attrs
      |> Enum.into(%{
        info_product_family_code: "code",
        info_version: "1",
        instance_contact_email: "example@example.com",
        instance_guid: "2u9dfh7979hfd",
        instance_name: "none",
        institution_id: map.institution.id,
        author_id: map.author.id
      })

    {:ok, consumer} =
      LtiToolConsumer.changeset(%LtiToolConsumer{}, params)
      |> Repo.insert()

    case tag do
      nil -> map
      t -> Map.put(map, t, consumer)
    end
  end

  def add_page(map, attrs, tag \\ nil) do

    author = map.author
    project = map.project
    publication = map.publication

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert

    attrs = Map.merge(%{author_id: author.id, objectives: %{ "attached" => []}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"), children: [], content: %{ "model" => []}, deleted: false, title: "title", resource_id: resource.id}, attrs)
    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, revision)
    end
  end

  def add_activity(map, attrs, tag \\ nil) do

    author = map.author
    project = map.project
    publication = map.publication

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert

    attrs = Map.merge(%{activity_type_id: 1, author_id: author.id, objectives: %{ "attached" => []}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"), children: [], content: %{}, deleted: false, title: "test", resource_id: resource.id}, attrs)

    {:ok, revision} = Oli.Resources.create_revision(attrs)
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, revision)
    end
  end

  def create_activity(attrs, publication, project, author) do

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert

    attrs = Map.merge(%{activity_type_id: 1, author_id: author.id, objectives: %{ "attached" => []}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"), children: [], content: %{}, deleted: false, title: "test", resource_id: resource.id}, attrs)

    {:ok, revision} = Oli.Resources.create_revision(attrs)
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def add_activity(map, attrs, publication_tag, project_tag, author_tag, resource_tag, revision_tag) do

    author = Map.get(map, author_tag)
    project = Map.get(map, project_tag)
    publication = Map.get(map, publication_tag)

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert

    attrs = Map.merge(%{activity_type_id: 1, author_id: author.id, objectives: %{ "attached" => []}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"), children: [], content: %{}, deleted: false, title: "test", resource_id: resource.id}, attrs)

    {:ok, revision} = Oli.Resources.create_revision(attrs)
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    Map.put(map, resource_tag, resource)
    |> Map.put(revision_tag, revision)
  end

  def attach_pages_to(resources, container, container_revision, publication) do

    children = Enum.map(resources, fn r -> r.id end)
    {:ok, updated} = Oli.Resources.update_revision(container_revision, %{children: children})

    Publishing.get_resource_mapping!(publication.id, container.id)
      |> Publishing.update_resource_mapping(%{revision_id: updated.id})

    updated
  end

  def add_objective(%{ project: project, publication: publication, author: author} = map, title, tag \\ nil) do

    {:ok, resource} = Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert
    {:ok, revision} = Oli.Resources.create_revision(%{author_id: author.id, objectives: %{}, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"), children: [], content: %{}, deleted: false, title: title, resource_id: resource.id})
    {:ok, _} = Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{project_id: project.id, resource_id: resource.id}) |> Repo.insert

    publish_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, revision)
    end
  end

  def add_author(%{ project: project} = map, author, atom) do
    {:ok, _} = AuthorProject.changeset(%AuthorProject{}, %{author_id: author.id, project_id: project.id, project_role_id: ProjectRole.role_id.owner}) |> Repo.insert
    Map.put(map, atom, author)
  end

end
