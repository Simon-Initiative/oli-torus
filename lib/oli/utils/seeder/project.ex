defmodule Oli.Utils.Seeder.Project do
  import Oli.Utils.Seeder.Utils

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Inventories
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Utils.Seeder
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Accounts.{SystemRole, ProjectRole, Author}
  alias Oli.Activities
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Inventories
  alias Oli.Activities
  alias Oli.Resources
  alias Oli.Utils.DataGenerators.NameGenerator
  alias Oli.Utils.Slug
  alias Oli.Activities.Model.Feedback
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Delivery.Sections.Blueprint

  @doc """
  Creates an author
  """
  def create_author(seeds, tags \\ []) do
    author_tag = tags[:author_tag]

    given_name = NameGenerator.first_name()
    family_name = NameGenerator.last_name()
    name = "#{given_name} #{family_name}"

    {:ok, author} =
      Author.noauth_changeset(%Author{}, %{
        email: "#{Slug.slugify(name)}@test.com",
        given_name: given_name,
        family_name: family_name,
        system_role_id: SystemRole.role_id().author
      })
      |> Repo.insert()

    seeds
    |> tag(author_tag, author)
  end

  @doc """
  Creates a sample project
  """
  def create_sample_project(seeds, author, tags \\ []) do
    [author] = unpack(seeds, [author])
    project_tag = tags[:project_tag] || random_tag()
    publication_tag = tags[:publication_tag] || random_tag()

    curriculum_revision_tag = tags[:curriculum_revision_tag] || random_tag()

    unit1_tag = tags[:unit1_tag] || random_tag()
    unscored_page1_tag = tags[:unscored_page1_tag] || random_tag()
    scored_page2_tag = tags[:scored_page2_tag] || random_tag()

    unscored_page1_activity_tag = tags[:unscored_page1_activity_tag] || random_tag()

    scored_page2_activity_tag = tags[:scored_page2_activity_tag] || random_tag()

    seeds =
      seeds
      |> Seeder.Project.create_project(
        author,
        %{},
        project_tag: project_tag,
        publication_tag: publication_tag,
        curriculum_revision_tag: curriculum_revision_tag
      )
      |> Seeder.Project.create_container(
        author,
        ref(project_tag),
        ref(curriculum_revision_tag),
        %{
          title: "Unit 1"
        },
        revision_tag: unit1_tag
      )

    seeds =
      seeds
      |> Seeder.Project.create_mcq_activity(
        author,
        ref(project_tag),
        ref(publication_tag),
        Feedback.from_text("an unscored activity explanation"),
        activity_tag: unscored_page1_activity_tag
      )
      |> Seeder.Project.create_mcq_activity(
        author,
        ref(project_tag),
        ref(publication_tag),
        Feedback.from_text("a scored activity explanation"),
        activity_tag: scored_page2_activity_tag
      )

    seeds =
      seeds
      |> Seeder.Project.create_page(
        author,
        ref(project_tag),
        ref(unit1_tag),
        %{
          title: "Unscored page one",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => seeds[unscored_page1_activity_tag].resource_id
              }
            ]
          },
          graded: false
        },
        revision_tag: unscored_page1_tag
      )
      |> Seeder.Project.create_page(
        author,
        ref(project_tag),
        ref(unit1_tag),
        %{
          title: "Scored page two",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => seeds[scored_page2_activity_tag].resource_id
              }
            ]
          },
          graded: true
        },
        revision_tag: scored_page2_tag
      )

    seeds
    |> tag(:project_tag, project_tag)
    |> tag(:publication_tag, publication_tag)
    |> tag(:unit1_tag, unit1_tag)
    |> tag(:unscored_page1_tag, unscored_page1_tag)
    |> tag(:scored_page2_tag, scored_page2_tag)
  end

  @doc """
  Creates a sample project
  """
  def create_product(seeds, title, project, tags \\ []) do
    [project] = unpack(seeds, [project])
    product_tag = tags[:product_tag]

    {:ok, product} = Blueprint.create_blueprint(project.slug, title, nil)

    seeds
    |> tag(product_tag, product)
  end

  @doc """
  Ensures a given publication is published
  """
  def ensure_published(seeds, publication, tags \\ []) do
    [publication] = unpack(seeds, [publication])
    publication_tag = tags[:publication_tag]

    publication =
      case publication do
        %Publication{published: nil} ->
          project = Oli.Authoring.Course.get_project!(publication.project_id)
          {:ok, published} = Oli.Publishing.publish_project(project, "ensure published")

          published

        already_published ->
          already_published
      end

    seeds
    |> tag(publication_tag, publication)
  end

  def create_project(seeds, author, attrs \\ %{}, tags \\ []) do
    author = maybe_ref(author, seeds)

    project_tag = tags[:project_tag]
    family_tag = tags[:family_tag]
    author_tag = tags[:author_tag]
    publication_tag = tags[:publication_tag]
    curriculum_resource_tag = tags[:curriculum_resource_tag]
    curriculum_revision_tag = tags[:curriculum_revision_tag]

    {:ok, family} =
      Family.changeset(%Family{}, %{description: "Sample Project Family", title: "Sample"})
      |> Repo.insert()

    publisher = Inventories.default_publisher()

    attrs =
      %{
        title: "Sample Project",
        description: "description",
        version: "1"
      }
      |> Map.merge(attrs)
      |> Map.merge(%{
        family_id: family.id,
        publisher_id: publisher.id
      })

    {:ok, project} =
      Project.changeset(%Project{}, attrs)
      |> Repo.insert()

    {:ok, _} =
      AuthorProject.changeset(%AuthorProject{}, %{
        author_id: author.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      })
      |> Repo.insert()

    # A single container resource with a mapped revision
    {:ok, curriculum_resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: curriculum_resource.id
      })
      |> Repo.insert()

    {:ok, curriculum_revision} =
      Oli.Resources.create_revision(%{
        author_id: author.id,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [],
        content: %{},
        deleted: false,
        slug: "curriculum",
        title: "Curriculum",
        resource_id: curriculum_resource.id
      })

    {:ok, publication} =
      Publication.changeset(%Publication{}, %{
        root_resource_id: curriculum_resource.id,
        project_id: project.id
      })
      |> Repo.insert()

    Publishing.create_published_resource(%{
      publication_id: publication.id,
      resource_id: curriculum_resource.id,
      revision_id: curriculum_revision.id
    })

    seeds
    |> tag(family_tag, family)
    |> tag(project_tag, project)
    |> tag(author_tag, author)
    |> tag(publication_tag, publication)
    |> tag(curriculum_resource_tag, curriculum_resource)
    |> tag(curriculum_revision_tag, curriculum_revision)
  end

  def create_page(
        seeds,
        author,
        project,
        attach_to_container_revision,
        attrs \\ %{},
        tags \\ []
      ) do
    [author, project, attach_to_container_revision] =
      unpack(seeds, [author, project, attach_to_container_revision])

    publication = Publishing.project_working_publication(project.slug)
    published_resource_tag = tags[:published_resource_tag] || random_tag()

    resource_tag = tags[:resource_tag]
    revision_tag = tags[:revision_tag]

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      %{
        title: "New Page",
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        content: %{"model" => []}
      }
      |> Map.merge(attrs)
      |> Map.merge(%{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        children: [],
        author_id: author.id,
        resource_id: resource.id,
        deleted: false
      })

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    seeds
    |> create_published_resource(
      publication,
      resource,
      revision,
      published_resource_tag: published_resource_tag
    )
    |> attach_to([resource], attach_to_container_revision, publication)
    |> tag(resource_tag, resource)
    |> tag(revision_tag, revision)
  end

  def create_container(
        seeds,
        author,
        project,
        attach_to_container_revision,
        attrs \\ %{},
        tags \\ []
      ) do
    [author, project, attach_to_container_revision] =
      unpack(seeds, [author, project, attach_to_container_revision])

    publication = Publishing.project_working_publication(project.slug)
    published_resource_tag = tags[:published_resource_tag] || random_tag()

    resource_tag = tags[:resource_tag]
    revision_tag = tags[:revision_tag]

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    attrs =
      %{
        title: "New Container",
        objectives: %{},
        children: []
      }
      |> Map.merge(attrs)
      |> Map.merge(%{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        content: %{},
        author_id: author.id,
        resource_id: resource.id,
        deleted: false
      })

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    seeds
    |> create_published_resource(
      publication,
      resource,
      revision,
      published_resource_tag: published_resource_tag
    )
    |> attach_to([resource], attach_to_container_revision, publication)
    |> tag(resource_tag, resource)
    |> tag(revision_tag, revision)
  end

  def create_mcq_activity(
        seeds,
        author,
        project,
        publication,
        explanation \\ nil,
        tags \\ []
      ) do
    [author, project, publication] = unpack(seeds, [author, project, publication])
    activity_tag = tags[:activity_tag] || random_tag()

    content = %{
      "stem" => "Example MCQ activity. Correct answer is 'Choice A'",
      "authoring" => %{
        "parts" => [
          maybe_add_explanation(
            %{
              "id" => "1",
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "responses" => [
                %{
                  "rule" => "input like {3222237681}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{
                    "id" => "1",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "Correct"
                          }
                        ],
                        "id" => "2624267862",
                        "type" => "p"
                      }
                    ]
                  }
                },
                %{
                  "rule" => "input like {1945694347}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{
                    "id" => "2",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "Almost"
                          }
                        ],
                        "id" => "2624267863",
                        "type" => "p"
                      }
                    ]
                  }
                },
                %{
                  "rule" => "input like {1945694348}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{
                    "id" => "3",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "No"
                          }
                        ],
                        "id" => "2624267864",
                        "type" => "p"
                      }
                    ]
                  }
                }
              ]
            },
            explanation
          )
        ]
      },
      "choices" => [
        %{
          "content" => [
            %{
              "children" => [
                %{
                  "text" => "Choice A"
                }
              ],
              "id" => "644441764",
              "type" => "p"
            }
          ],
          "id" => "3222237681"
        },
        %{
          "content" => [
            %{
              "children" => [
                %{
                  "text" => "Choice B"
                }
              ],
              "id" => "2252168149",
              "type" => "p"
            }
          ],
          "id" => "1945694347"
        },
        %{
          "content" => [
            %{
              "children" => [
                %{
                  "text" => "Choice C"
                }
              ],
              "id" => "2252168150",
              "type" => "p"
            }
          ],
          "id" => "1945694348"
        }
      ]
    }

    seeds
    |> create_activity(
      author,
      project,
      publication,
      %{title: "Exmaple MCQ Activity", content: content},
      revision_tag: activity_tag
    )
  end

  def set_revision_max_attempts(
        seeds,
        revision,
        max_attempts
      ) do
    [revision] = unpack(seeds, [revision])

    Resources.update_revision(revision, %{max_attempts: max_attempts})

    seeds
  end

  def set_revision_explanation_strategy(
        seeds,
        revision,
        %ExplanationStrategy{} = strategy
      ) do
    [revision] = unpack(seeds, [revision])

    Resources.update_revision(revision, %{explanation_strategy: Map.from_struct(strategy)})

    seeds
  end

  defp maybe_add_explanation(content, nil), do: content

  defp maybe_add_explanation(content, explanation),
    do: Map.put(content, "explanation", explanation)

  def create_activity(seeds, author, project, publication, attrs, tags \\ nil) do
    [author, project, publication] = unpack(seeds, [author, project, publication])

    {:ok, resource} =
      Oli.Resources.Resource.changeset(%Oli.Resources.Resource{}, %{}) |> Repo.insert()

    attrs =
      %{
        activity_type_id: Activities.get_registration_by_slug("oli_multiple_choice").id,
        objectives: %{},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("best"),
        content: %{},
        title: "test"
      }
      |> Map.merge(attrs)
      |> Map.merge(%{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        children: [],
        author_id: author.id,
        resource_id: resource.id,
        deleted: false
      })

    {:ok, revision} = Oli.Resources.create_revision(attrs)

    {:ok, _} =
      Oli.Authoring.Course.ProjectResource.changeset(%Oli.Authoring.Course.ProjectResource{}, %{
        project_id: project.id,
        resource_id: resource.id
      })
      |> Repo.insert()

    create_published_resource(seeds, publication, resource, revision)

    seeds
    |> tag(tags[:resource_tag], resource)
    |> tag(tags[:revision_tag], revision)
  end

  defp create_published_resource(seeds, publication, resource, revision, tags \\ []) do
    published_resource_tag = tags[:published_resource_tag]

    {:ok, published_resource} =
      Publishing.create_published_resource(%{
        publication_id: publication.id,
        resource_id: resource.id,
        revision_id: revision.id
      })

    seeds
    |> tag(published_resource_tag, published_resource)
  end

  defp attach_to(seeds, resources, container_revision, publication) do
    children_ids = Enum.map(resources, fn r -> r.id end)

    {:ok, updated} =
      Oli.Resources.create_revision_from_previous(container_revision, %{children: container_revision.children ++ children_ids})

    Publishing.get_published_resource!(publication.id, container_revision.resource_id)
    |> Publishing.update_published_resource(%{revision_id: updated.id})

    seeds
  end

  def resolve(seeds, project, revision, tags) do
    [project, revision] = unpack(seeds, [project, revision])

    revision = AuthoringResolver.from_resource_id(project.slug, revision.resource_id)

    seeds
    |> tag(tags[:revision_tag], revision)
  end
end
