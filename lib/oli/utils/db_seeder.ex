defmodule Oli.Seeder do
  import Ecto.Query, warn: false
  import Oli.Delivery.Attempts.Core

  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Accounts.{SystemRole, ProjectRole, Author}
  alias Oli.Institutions.Institution
  alias Oli.Delivery.Attempts.Core.{ResourceAccess}
  alias Oli.Activities
  alias Oli.Activities.Model.Part
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing.Publication
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Qa.Reviews
  alias Oli.Activities
  alias Oli.Delivery.Gating

  def base_project_with_resource(author) do
    {:ok, family} =
      Family.changeset(%Family{}, %{description: "description", title: "title"}) |> Repo.insert()

    {:ok, project} =
      Project.changeset(%Project{}, %{
        description: "description",
        title: "Example Course",
        version: "1",
        family_id: family.id
      })
      |> Repo.insert()

    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      })
      |> Repo.insert()

    {:ok, institution} =
      Institution.changeset(%Institution{}, %{
        name: "Example Institution",
        country_code: "US",
        institution_email: author.email,
        institution_url: "example.edu",
        timezone: "America/New_York"
      })
      |> Repo.insert()

    # A single container resource with a mapped revision
    {:ok, container_resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: container_resource.id
      })
      |> Repo.insert()

    {:ok, container_revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Curriculum",
        resource_id: container_resource.id
      })

    {:ok, publication} =
      Publication.changeset(%Publication{}, %{
        root_resource_id: container_resource.id,
        project_id: project.id
      })
      |> Repo.insert()

    create_published_resource(publication, container_resource, container_revision)

    %{resource: page1, revision: revision1} =
      create_page("Page one", publication, project, author)

    %{resource: page2, revision: revision2} =
      create_page("Page two", publication, project, author, create_sample_content())

    container_revision =
      attach_pages_to([page1, page2], container_resource, container_revision, publication)

    Map.put(%{}, :family, family)
    |> Map.put(:project, project)
    |> Map.put(:author, author)
    |> Map.put(:institution, institution)
    |> Map.put(:publication, publication)
    |> Map.put(:container, %{resource: container_resource, revision: container_revision})
    |> Map.put(:page1, page1)
    |> Map.put(:page2, page2)
    |> Map.put(:revision1, revision1)
    |> Map.put(:revision2, revision2)
  end

  def base_project_with_resource2() do
    {:ok, family} =
      Family.changeset(%Family{}, %{description: "description", title: "title"}) |> Repo.insert()

    {:ok, project} =
      Project.changeset(%Project{}, %{
        description: "description",
        title: "Example Open and Free Course",
        version: "1",
        family_id: family.id
      })
      |> Repo.insert()

    {:ok, author} =
      Author.noauth_changeset(%Author{}, %{
        email: "test#{System.unique_integer([:positive])}@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: SystemRole.role_id().author
      })
      |> Repo.insert()

    {:ok, author2} =
      Author.noauth_changeset(%Author{}, %{
        email: "test#{System.unique_integer([:positive])}@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: SystemRole.role_id().author
      })
      |> Repo.insert()

    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      })
      |> Repo.insert()

    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author2.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      })
      |> Repo.insert()

    {:ok, institution} =
      Institution.changeset(%Institution{}, %{
        name: "CMU",
        country_code: "some country_code",
        institution_email: "some institution_email",
        institution_url: "some institution_url",
        timezone: "some timezone",
        author_id: author.id
      })
      |> Repo.insert()

    # A single container resource with a mapped revision
    {:ok, container_resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: container_resource.id
      })
      |> Repo.insert()

    {:ok, container_revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container",
        resource_id: container_resource.id
      })

    {:ok, publication} =
      Publication.changeset(%Publication{}, %{
        root_resource_id: container_resource.id,
        project_id: project.id
      })
      |> Repo.insert()

    create_published_resource(publication, container_resource, container_revision)

    %{resource: page1, revision: revision1} =
      create_page("Page one", publication, project, author)

    %{resource: page2, revision: revision2} =
      create_page("Page two", publication, project, author, create_sample_content())

    container_revision =
      attach_pages_to([page1, page2], container_resource, container_revision, publication)

    Map.put(%{}, :family, family)
    |> Map.put(:project, project)
    |> Map.put(:author, author)
    |> Map.put(:author2, author2)
    |> Map.put(:institution, institution)
    |> Map.put(:publication, publication)
    |> Map.put(:container, %{resource: container_resource, revision: container_revision})
    |> Map.put(:page1, page1)
    |> Map.put(:page2, page2)
    |> Map.put(:revision1, revision1)
    |> Map.put(:revision2, revision2)
  end

  def add_adaptive_page(
        %{project: project, publication: publication, author: author} = seed,
        activity_resource_tag \\ :adaptive_resource,
        activity_revision_tag \\ :adaptive_revision,
        page_resource_tag \\ :adaptive_page_resource,
        page_revision_tag \\ :adaptive_page_revision
      ) do
    # A minimal adaptive activity consisting of a single hello-world screen
    adaptive_content = %{
      "custom" => %{
        "x" => 0,
        "y" => 0,
        "z" => 0,
        "facts" => [],
        "width" => 1024,
        "height" => 800
      },
      "authoring" => %{
        "parts" => [
          %{
            "id" => "__default",
            "type" => "janus-text-flow",
            "owner" => "aa_4134662282",
            "inherited" => false
          }
        ],
        "rules" => [],
        "variablesRequiredForEvaluation" => [],
        "activitiesRequiredForEvaluation" => []
      },
      "partsLayout" => [
        %{
          "id" => "hello_world",
          "type" => "janus-text-flow",
          "custom" => %{
            "x" => 100,
            "y" => 213,
            "z" => 0,
            "nodes" => [
              %{
                "tag" => "p",
                "children" => [
                  %{
                    "tag" => "span",
                    "style" => %{},
                    "children" => [
                      %{
                        "tag" => "text",
                        "text" => "Hello World",
                        "children" => []
                      }
                    ]
                  }
                ]
              }
            ],
            "width" => 330,
            "height" => 22,
            "visible" => true,
            "overrideWidth" => true,
            "customCssClass" => "",
            "overrideHeight" => false
          }
        }
      ]
    }

    %{resource: activity_resource, revision: activity_revision} =
      create_activity(
        %{
          activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id,
          content: adaptive_content
        },
        publication,
        project,
        author
      )

    %{resource: page_resource, revision: page_revision} =
      create_page(
        "Seeded Adaptive Page",
        publication,
        project,
        author,
        create_sample_adaptive_page_content(activity_revision.resource_id)
      )

    seed
    |> Map.put(page_resource_tag, page_resource)
    |> Map.put(page_revision_tag, page_revision)
    |> Map.put(activity_resource_tag, activity_resource)
    |> Map.put(activity_revision_tag, activity_revision)
  end

  def base_project_with_resource3() do
    mappings = base_project_with_resource2()

    %{
      container: %{resource: container_resource, revision: container_revision},
      publication: publication,
      project: project,
      author: author
    } = mappings

    %{resource: unit1_resource, revision: unit1_revision} =
      create_container("Unit 1", publication, project, author)

    # create some nested children
    %{resource: nested_page1, revision: nested_revision1} =
      create_page("Nested Page One", publication, project, author)

    %{resource: nested_page2, revision: nested_revision2} =
      create_page("Nested Page Two", publication, project, author, create_sample_content())

    unit1_revision =
      attach_pages_to([nested_page1, nested_page2], unit1_resource, unit1_revision, publication)

    container_revision =
      attach_pages_to([unit1_resource], container_resource, container_revision, publication)

    Map.merge(mappings, %{
      container: %{resource: container_resource, revision: container_revision},
      unit1_container: %{resource: unit1_resource, revision: unit1_revision},
      nested_page1: nested_page1,
      nested_revision1: nested_revision1,
      nested_page2: nested_page2,
      nested_revision2: nested_revision2
    })
  end

  def base_project_with_resource4() do
    map =
      base_project_with_resource3()
      |> add_objective("child1", :child1)
      |> add_objective("child2", :child2)
      |> add_objective("child3", :child3)
      |> add_objective("child4", :child4)
      |> add_objective_with_children("parent1", [:child1, :child2, :child3], :parent1)
      |> add_objective_with_children("parent2", [:child4], :parent2)

    # Create another project with resources and revisions
    project2_map = another_project(map.author, map.institution)

    # Publish the current state of our test project:
    {:ok, pub1} = Publishing.publish_project(map.project, "some changes")

    # Track a series of changes for both resources:
    pub = Publishing.project_working_publication(map.project.slug)

    latest1 =
      Publishing.publish_new_revision(map.revision1, %{title: "1"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "2"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "3"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "4"}, pub, map.author.id)

    latest2 =
      Publishing.publish_new_revision(map.revision2, %{title: "A"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "B"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "C"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{title: "D"}, pub, map.author.id)

    # Create a new page that wasn't present during the first publication
    %{revision: latest3} = create_page("New To Pub2", pub, map.project, map.author)

    second_map = add_objective(Map.merge(map, %{publication: pub}), "child5", :child5)

    second_map =
      add_objective_with_children(
        Map.merge(second_map, %{publication: pub}),
        "parent3",
        [:child5],
        :parent3
      )

    # Publish again
    {:ok, pub2} = Publishing.publish_project(map.project, "some changes")

    # Create a fourth page that is completely unpublished
    pub = Publishing.project_working_publication(map.project.slug)
    %{revision: latest4} = create_page("Unpublished", pub, map.project, map.author)

    third_map = add_objective(Map.merge(map, %{publication: pub}), "child6", :child6)

    third_map =
      add_objective_with_children(
        Map.merge(third_map, %{publication: pub}),
        "parent4",
        [:child6],
        :parent4
      )

    # Create a course section, one for each publication
    {:ok, section_1} =
      Sections.create_section(%{
        title: "1",
        timezone: "1",
        registration_open: true,
        context_id: UUID.uuid4(),
        institution_id: map.institution.id,
        base_project_id: map.project.id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub1)

    {:ok, section_2} =
      Sections.create_section(%{
        title: "2",
        timezone: "1",
        registration_open: true,
        context_id: UUID.uuid4(),
        institution_id: map.institution.id,
        base_project_id: map.project.id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub2)

    {:ok, oaf_section_1} =
      Sections.create_section(%{
        title: "3",
        timezone: "1",
        registration_open: true,
        open_and_free: true,
        context_id: UUID.uuid4(),
        institution_id: map.institution.id,
        base_project_id: map.project.id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub2)

    Map.put(map, :latest1, latest1)
    |> Map.put(:latest2, latest2)
    |> Map.put(:pub1, pub1)
    |> Map.put(:pub2, pub2)
    |> Map.put(:latest3, latest3)
    |> Map.put(:latest4, latest4)
    |> Map.put(:child5, Map.get(second_map, :child5))
    |> Map.put(:parent3, Map.get(second_map, :parent3))
    |> Map.put(:child6, Map.get(third_map, :child6))
    |> Map.put(:parent4, Map.get(third_map, :parent4))
    |> Map.put(:section_1, section_1)
    |> Map.put(:section_2, section_2)
    |> Map.put(:oaf_section_1, oaf_section_1)
    |> Map.put(:project2, project2_map.project)
    |> Map.put(:project2_map, project2_map)
  end

  def create_section(map) do
    params = %{
      end_date: ~U[2010-04-17 00:00:00.000000Z],
      open_and_free: false,
      registration_open: true,
      start_date: ~U[2010-04-17 00:00:00.000000Z],
      timezone: "some timezone",
      title: "some title",
      context_id: UUID.uuid4(),
      base_project_id: map.project.id,
      institution_id: map.institution.id
    }

    {:ok, section} =
      Section.changeset(%Section{}, params)
      |> Repo.insert()

    Map.put(map, :section, section)
  end

  def create_product(map, attrs, tag) do
    params =
      Map.merge(
        %{
          end_date: ~U[2010-04-17 00:00:00.000000Z],
          type: :blueprint,
          registration_open: true,
          start_date: ~U[2010-04-17 00:00:00.000000Z],
          timezone: "some timezone",
          title: "some title",
          description: "a description",
          context_id: UUID.uuid4(),
          base_project_id: map.project.id,
          institution_id: map.institution.id
        },
        attrs
      )

    {:ok, section} =
      Section.changeset(%Section{}, params)
      |> Repo.insert()

    Map.put(map, tag, section)
  end

  def create_section_resources(%{section: section, publication: publication} = map) do
    {:ok, section} =
      section
      |> Sections.create_section_resources(publication)

    Map.put(map, :section, section)
  end

  def rebuild_section_resources(
        %{section: %Section{id: section_id} = section, publication: publication} = map
      ) do
    section
    |> Section.changeset(%{root_section_resource_id: nil})
    |> Repo.update!()

    from(sr in SectionResource,
      where: sr.section_id == ^section_id
    )
    |> Repo.delete_all()

    from(spp in SectionsProjectsPublications,
      where: spp.section_id == ^section_id
    )
    |> Repo.delete_all()

    {:ok, section} =
      section
      |> Sections.create_section_resources(publication)

    Map.put(map, :section, section)
  end

  def another_project(author, institution, title \\ "title") do
    {:ok, family} =
      Family.changeset(%Family{}, %{description: "description", title: "title"}) |> Repo.insert()

    {:ok, project} =
      Project.changeset(%Project{}, %{
        description: "description",
        title: title,
        version: "1",
        family_id: family.id
      })
      |> Repo.insert()

    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      })
      |> Repo.insert()

    # A single container resource with a mapped revision
    {:ok, container_resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: container_resource.id
      })
      |> Repo.insert()

    {:ok, container_revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [],
        content: %{},
        deleted: false,
        slug: "some_title",
        title: "some title",
        resource_id: container_resource.id
      })

    {:ok, publication} =
      Publication.changeset(%Publication{}, %{
        root_resource_id: container_resource.id,
        project_id: project.id
      })
      |> Repo.insert()

    create_published_resource(publication, container_resource, container_revision)

    %{resource: page1, revision: revision1} =
      create_page("Page one", publication, project, author)

    %{resource: page2, revision: revision2} =
      create_page("Page two", publication, project, author)

    container_revision =
      attach_pages_to([page1, page2], container_resource, container_revision, publication)

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
  end

  def create_resource_attempt(map, attrs, user_tag, resource_tag, tag) do
    user = Map.get(map, user_tag)
    resource = Map.get(map, resource_tag).resource
    revision = Map.get(map, resource_tag).revision
    section = map.section

    %ResourceAccess{id: id} = track_access(resource.id, section.id, user.id)

    attrs =
      Map.merge(attrs, %{
        resource_access_id: id,
        revision_id: revision.id,
        attempt_guid: UUID.uuid4(),
        errors: [],
        content: revision.content
      })

    {:ok, attempt} = create_resource_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  def create_resource_attempt(map, attrs, user_tag, resource_tag, revision_tag, tag) do
    user = Map.get(map, user_tag)
    resource = Map.get(map, resource_tag)
    revision = Map.get(map, revision_tag)
    section = map.section

    %ResourceAccess{id: id} = track_access(resource.id, section.id, user.id)

    attrs =
      Map.merge(attrs, %{
        resource_access_id: id,
        revision_id: revision.id,
        attempt_guid: UUID.uuid4(),
        errors: [],
        content: revision.content
      })

    {:ok, attempt} = create_resource_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  def create_activity_attempt(map, attrs, activity_tag, attempt_tag, tag \\ nil) do
    resource_attempt = Map.get(map, attempt_tag)
    resource = Map.get(map, activity_tag).resource
    revision = Map.get(map, activity_tag).revision

    attrs =
      Map.merge(attrs, %{
        resource_attempt_id: resource_attempt.id,
        revision_id: revision.id,
        resource_id: resource.id,
        attempt_guid: UUID.uuid4()
      })

    {:ok, attempt} = create_activity_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  def create_part_attempt(map, attrs, %Part{} = part, attempt_tag, tag \\ nil) do
    activity_attempt = Map.get(map, attempt_tag)

    attrs =
      Map.merge(attrs, %{
        activity_attempt_id: activity_attempt.id,
        part_id: part.id,
        attempt_guid: UUID.uuid4()
      })

    {:ok, attempt} = create_part_attempt(attrs)

    case tag do
      nil -> map
      t -> Map.put(map, t, attempt)
    end
  end

  def ensure_published(publication_id) do
    case Repo.get(Publication, publication_id) do
      nil ->
        true

      %Publication{published: nil} = p ->
        Oli.Publishing.update_publication(p, %{published: DateTime.utc_now()})
    end

    query = """
    REFRESH MATERIALIZED VIEW part_mapping;
    """

    Oli.Repo.query!(query, [])
  end

  defp create_published_resource(publication, resource, revision) do
    Publishing.create_published_resource(%{
      publication_id: publication.id,
      resource_id: resource.id,
      revision_id: revision.id
    })
  end

  def create_page(title, publication, project, author, content \\ %{"model" => []}) do
    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        children: [],
        content: content,
        deleted: false,
        title: title,
        resource_id: resource.id
      })

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def create_container(title, publication, project, author, children \\ []) do
    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    {:ok, revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: children,
        content: %{},
        deleted: false,
        slug: Oli.Utils.Slug.generate("revisions", title),
        title: title,
        resource_id: resource.id
      })

    create_published_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def create_sample_adaptive_page_content(activity_resource_id) do
    %{
      "advancedDelivery" => true,
      "advancedAuthoring" => true,
      "model" => [
        %{
          "id" => "1649184696677",
          "type" => "group",
          "layout" => "deck",
          "children" => [
            %{
              "type" => "activity-reference",
              "activity_id" => activity_resource_id
            }
          ]
        }
      ]
    }
  end

  def create_sample_content() do
    %{
      "model" => [
        %{
          "children" => [
            %{
              "children" => [
                %{
                  "text" => "Here's some test content"
                }
              ],
              "id" => "3371710400",
              "type" => "p"
            }
          ],
          "id" => "158828742",
          "purpose" => "none",
          "selection" => %{
            "anchor" => %{
              "offset" => 24,
              "path" => [
                0,
                0
              ]
            },
            "focus" => %{
              "offset" => 24,
              "path" => [
                0,
                0
              ]
            }
          },
          "type" => "content"
        }
      ]
    }
  end

  def add_user(map, attrs, tag \\ nil) do
    {:ok, user} =
      User.noauth_changeset(
        %User{
          sub: UUID.uuid4(),
          name: "Ms Jane Marie Doe",
          given_name: "Jane",
          family_name: "Doe",
          middle_name: "Marie",
          picture: "https://platform.example.edu/jane.jpg",
          email: "jane#{System.unique_integer([:positive])}@platform.example.edu",
          locale: "en-US",
          independent_learner: false,
          age_verified: true
        },
        attrs
      )
      |> Repo.insert()

    case tag do
      nil -> map
      t -> Map.put(map, t, user)
    end
  end

  def add_users_to_section(map, section_tag, user_tags) do
    # Make users
    map =
      user_tags
      |> Enum.with_index()
      |> Enum.reduce(
        map,
        fn {tag, index}, acc ->
          add_user(
            acc,
            %{
              sub: Atom.to_string(tag),
              given_name: "Jane",
              family_name: "Doe",
              email: "jane#{index}@platform.example.edu"
            },
            tag
          )
        end
      )

    # Enroll users
    user_tags
    |> Enum.each(fn user_tag ->
      Sections.enroll(map[user_tag].id, map[section_tag].id, [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
      ])
    end)

    map
  end

  def create_hierarchy(map, nodes) do
    author = map.author
    project = map.project
    publication = map.publication
    container_revision = map.container.revision
    container_resource = map.container.resource

    children =
      Enum.map(nodes, fn n -> create_hierarchy_helper(author, project, publication, n) end)
      |> Enum.map(fn rev -> rev.resource_id end)

    {:ok, container_revision} =
      Oli.Resources.update_revision(container_revision, %{children: children})

    Publishing.upsert_published_resource(publication, container_revision)

    Map.put(map, :container, %{resource: container_resource, revision: container_revision})
  end

  def create_hierarchy_helper(author, project, publication, node) do
    created =
      Enum.map(node.children, fn node ->
        create_hierarchy_helper(author, project, publication, node)
      end)

    children = Enum.map(created, fn rev -> rev.resource_id end)

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs = %{
      author_id: author.id,
      objectives: %{},
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
      children: children,
      content: %{},
      deleted: false,
      title: node.title,
      resource_id: resource.id
    }

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    revision
  end

  def add_page(map, attrs, container_tag \\ :container, tag) do
    author = map.author
    project = map.project
    publication = map.publication

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      Map.merge(
        %{
          author_id: author.id,
          objectives: %{"attached" => []},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          children: [],
          content: %{"model" => []},
          deleted: false,
          title: "title",
          resource_id: resource.id
        },
        attrs
      )

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)
    %{revision: container_revision, resource: container_resource} = Map.get(map, container_tag)

    container_revision =
      attach_pages_to([resource], container_resource, container_revision, publication)

    map
    |> Map.put(tag, %{revision: revision, resource: resource})
    |> Map.update(container_tag, map[container_tag], &%{&1 | revision: container_revision})
  end

  def create_tag(map, title, tag) do
    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs = %{
      author_id: Map.get(map, :author).id,
      title: title,
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("tag"),
      resource_id: resource.id
    }

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: Map.get(map, :project).id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(Map.get(map, :publication), resource, revision)

    Map.put(map, tag, %{resource: resource, revision: revision})
  end

  def create_activity(attrs, publication, project, author) do
    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      Map.merge(
        %{
          activity_type_id: Activities.get_registration_by_slug("oli_multiple_choice").id,
          author_id: author.id,
          objectives: %{"attached" => []},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
          children: [],
          content: %{},
          deleted: false,
          title: "test",
          resource_id: resource.id
        },
        attrs
      )

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    %{resource: resource, revision: revision}
  end

  def add_activity(map, attrs, tag \\ nil) do
    author = map.author
    project = map.project
    publication = map.publication

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      Map.merge(
        %{
          activity_type_id: Activities.get_registration_by_slug("oli_multiple_choice").id,
          author_id: author.id,
          objectives: %{},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
          children: [],
          content: %{},
          deleted: false,
          title: "test",
          resource_id: resource.id
        },
        attrs
      )

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, %{revision: revision, resource: resource})
    end
  end

  def add_activity(map, attrs, publication_tag, project_tag, author_tag, activity_tag) do
    add_activity(
      map,
      attrs,
      publication_tag,
      project_tag,
      author_tag,
      activity_tag,
      Activities.get_registration_by_slug("oli_multiple_choice").id
    )
  end

  def add_activity(
        map,
        attrs,
        publication_tag,
        project_tag,
        author_tag,
        activity_tag,
        activity_type_id
      ) do
    author = Map.get(map, author_tag)
    project = Map.get(map, project_tag)
    publication = Map.get(map, publication_tag)

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      Map.merge(
        %{
          activity_type_id: activity_type_id,
          author_id: author.id,
          objectives: %{"attached" => []},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
          children: [],
          content: %{},
          deleted: false,
          title: "test",
          resource_id: resource.id
        },
        attrs
      )

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    map
    |> Map.put(activity_tag, %{resource: resource, revision: revision})
  end

  def attach_pages_to(resources, container, container_revision, publication) do
    new_children = Enum.map(resources, fn r -> r.id end)

    set_container_children(
      container_revision.children ++ new_children,
      container,
      container_revision,
      publication
    )
  end

  def delete_page(page, page_revision, container, container_revision, publication) do
    new_children = Enum.filter(container_revision.children, fn id -> id != page.id end)

    set_container_children(
      new_children,
      container,
      container_revision,
      publication
    )

    {:ok, updated} = Oli.Resources.create_revision_from_previous(page_revision, %{deleted: true})

    Publishing.get_published_resource!(publication.id, page.id)
    |> Publishing.update_published_resource(%{revision_id: updated.id})

    updated
  end

  def replace_pages_with(resources, container, container_revision, publication) do
    children = Enum.map(resources, fn r -> r.id end)
    set_container_children(children, container, container_revision, publication)
  end

  defp set_container_children(children, container, container_revision, publication) do
    {:ok, updated} =
      Oli.Resources.create_revision_from_previous(container_revision, %{children: children})

    Publishing.get_published_resource!(publication.id, container.id)
    |> Publishing.update_published_resource(%{revision_id: updated.id})

    updated
  end

  def revise_page(changes, container, container_revision, publication) do
    {:ok, updated} = Oli.Resources.create_revision_from_previous(container_revision, changes)

    Publishing.get_published_resource!(publication.id, container.id)
    |> Publishing.update_published_resource(%{revision_id: updated.id})

    updated
  end

  def add_objective(
        %{project: project, publication: publication, author: author} = map,
        title,
        tag \\ nil
      ) do
    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"),
        children: [],
        content: %{},
        deleted: false,
        title: title,
        resource_id: resource.id
      })

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, %{revision: revision, resource: resource})
    end
  end

  def add_objective_with_children(
        %{project: project, publication: publication, author: author} = map,
        title,
        children_tags,
        tag \\ nil
      ) do
    children = Enum.map(children_tags, fn tag -> Map.get(map, tag).revision.resource_id end)

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"),
        children: children,
        content: %{},
        deleted: false,
        title: title,
        resource_id: resource.id
      })

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(publication, resource, revision)

    case tag do
      nil -> map
      t -> Map.put(map, t, %{revision: revision, resource: resource})
    end
  end

  def add_collaborator(%{project: project} = map, author, atom) do
    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().contributor
      })
      |> Repo.insert()

    Map.put(map, atom, author)
  end

  def add_activity_snapshot(map, attrs, tag) do
    {:ok, snapshot} = Snapshot.changeset(%Snapshot{}, attrs) |> Repo.insert()
    Map.put(map, tag, snapshot)
  end

  def add_review(map, type, tag) do
    {:ok, review} = Reviews.create_review(Map.get(map, :project), type)

    map
    |> Map.put(tag, review)
  end

  def add_resource_accesses(map, section_tag, score_map) do
    # Effectful. Adds resource accesses with scores to DB, but does not add to map.
    score_map
    |> Map.to_list()
    |> Enum.each(fn {revision_tag, %{out_of: out_of, scores: scores}} ->
      scores
      |> Map.to_list()
      |> Enum.each(fn {user_tag, score} ->
        %ResourceAccess{}
        |> ResourceAccess.changeset(%{
          access_count: 1,
          score: score,
          out_of: out_of,
          user_id: map[user_tag].id,
          section_id: map[section_tag].id,
          # Revision tag is used some places as the real revision tag in the map, other times it's the
          # tag that points to the {resource, revision} pair
          resource_id:
            try do
              map[revision_tag].resource_id
            rescue
              _e -> map[revision_tag].resource.id
            end
        })
        |> Repo.insert()
      end)
    end)

    map
  end

  def create_schedule_gating_condition(start_datetime, end_datetime, resource_id, section_id) do
    {:ok, gating_condition} =
      Gating.create_gating_condition(%{
        type: :schedule,
        data: %{
          start_datetime: start_datetime,
          end_datetime: end_datetime
        },
        resource_id: resource_id,
        section_id: section_id
      })

    gating_condition
  end
end
