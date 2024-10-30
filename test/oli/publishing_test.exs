defmodule Oli.PublishingTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Oli.Factory
  import Ecto.Query
  import Oli.Utils.Seeder.Utils

  alias Oli.Publishing.Publications.PublicationDiff
  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Authoring.{Course, Locks}
  alias Oli.Authoring.Editing.{PageEditor, ObjectiveEditor, ActivityEditor}
  alias Oli.Activities
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources
  alias Oli.Resources.ResourceType
  alias Oli.Utils.Seeder

  def create_activity(parts, author, project, page_revision) do
    # Create a two part activity where each part is tied to one of the objectives above

    objectives =
      Enum.reduce(parts, %{}, fn {part_id, slugs}, m ->
        Map.put(m, part_id, slugs)
      end)

    parts = Enum.map(parts, fn {part_id, _} -> part_id end)
    content = %{"content" => %{"authoring" => %{"parts" => parts}}}

    {:ok, {revision, _}} =
      ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

    update = %{"objectives" => objectives}

    {:ok, revision} =
      ActivityEditor.edit(
        project.slug,
        page_revision.resource_id,
        revision.resource_id,
        author.email,
        update
      )

    revision
  end

  describe "create_resource_batch tests" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "create_resource_batch", %{
      project: project
    } do
      resource_ids = Publishing.create_resource_batch(project, 2)
      assert Enum.count(resource_ids) == 2

      assert Oli.Repo.all(
               from pr in Oli.Authoring.Course.ProjectResource,
                 where: pr.project_id == ^project.id and pr.resource_id in ^resource_ids
             )
             |> Enum.count() == 2

      assert Oli.Repo.all(
               from pr in Oli.Resources.Resource,
                 where: pr.id in ^resource_ids
             )
             |> Enum.count() == 2
    end

    test "ignores expired locks", %{
      author: author,
      project: project,
      publication: publication,
      container: %{resource: container_resource}
    } do
      assert Locks.acquire(project.slug, publication.id, container_resource.id, author.id) ==
               {:acquired}

      [published_resource] =
        Publishing.retrieve_lock_info([container_resource.id], publication.id)

      Publishing.update_published_resource(published_resource, %{lock_updated_at: yesterday()})

      assert [] = Publishing.retrieve_lock_info([container_resource.id], publication.id)
    end
  end

  describe "retrieve_lock_info" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "retrieves valid lock info", %{
      author: author,
      project: project,
      publication: publication,
      container: %{resource: container_resource}
    } do
      assert Locks.acquire(project.slug, publication.id, container_resource.id, author.id) ==
               {:acquired}

      id = container_resource.id

      assert [%PublishedResource{resource_id: ^id}] =
               Publishing.retrieve_lock_info([container_resource.id], publication.id)
    end

    test "ignores expired locks", %{
      author: author,
      project: project,
      publication: publication,
      container: %{resource: container_resource}
    } do
      assert Locks.acquire(project.slug, publication.id, container_resource.id, author.id) ==
               {:acquired}

      [published_resource] =
        Publishing.retrieve_lock_info([container_resource.id], publication.id)

      Publishing.update_published_resource(published_resource, %{lock_updated_at: yesterday()})

      assert [] = Publishing.retrieve_lock_info([container_resource.id], publication.id)
    end
  end

  describe "publications" do
    setup do
      Oli.Seeder.base_project_with_resource2()
      |> Oli.Seeder.add_objective("one", :one)
      |> Oli.Seeder.add_objective("two", :two)
    end

    test "find_objective_in_selections/2 finds the objectives", %{
      author: author,
      project: project,
      publication: publication,
      one: one,
      two: two
    } do
      content = %{
        "model" => [
          %{
            count: 1,
            id: "3591062038",
            logic: %{
              conditions: %{
                fact: "objectives",
                operator: "contains",
                value: [
                  one.resource.id
                ]
              }
            },
            purpose: "none",
            type: "selection"
          }
        ]
      }

      # Create two new pages, both that reference objective :one in selections

      {:ok, %{revision: revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: content,
          title: "resource 1",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision)

      {:ok, %{revision: revision2}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: content,
          title: "resource 2",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision2)

      results = Publishing.find_objective_in_selections(one.resource.id, publication.id)
      assert length(results) == 2
      assert Enum.empty?(Publishing.find_objective_in_selections(two.resource.id, publication.id))

      assert Enum.at(results, 0).title != Enum.at(results, 1).title

      assert Enum.at(results, 0).title == "resource 1" or
               Enum.at(results, 1).title == "resource 1"

      assert Enum.at(results, 0).title == "resource 2" or
               Enum.at(results, 1).title == "resource 2"
    end

    test "find_alternatives_group_references_in_pages/2 finds the group references", %{
      author: author,
      project: project,
      publication: publication
    } do
      # create alternatives group
      {:ok, %{revision: alt_group_revision_one}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{
            "options" => [
              %{"id" => "abc123", title: "alt 1 option 1"},
              %{"id" => "abc124", title: "alt 1 option 2"}
            ]
          },
          title: "alternatives group 1",
          resource_type_id: ResourceType.id_for_alternatives(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, alt_group_revision_one)

      # create alternatives group
      {:ok, %{revision: alt_group_revision_two}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{
            "options" => [
              %{"id" => "abc125", title: "alt 2 option 1"},
              %{"id" => "abc126", title: "alt 2 option 2"}
            ]
          },
          title: "alternatives group 2",
          resource_type_id: ResourceType.id_for_alternatives(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, alt_group_revision_two)

      content = %{
        "model" => [
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "children" => [
                          %{
                            "text" => ""
                          }
                        ],
                        "id" => "525920519",
                        "type" => "p"
                      }
                    ],
                    "id" => "2356581862",
                    "type" => "content"
                  }
                ],
                "id" => "1166618130",
                "type" => "alternative",
                "value" => "yPai54qGVbuRjEbQZEbEVN"
              },
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "children" => [
                          %{
                            "text" => ""
                          }
                        ],
                        "id" => "2607062372",
                        "type" => "p"
                      }
                    ],
                    "id" => "109635996",
                    "type" => "content"
                  }
                ],
                "id" => "2441342374",
                "type" => "alternative",
                "value" => "irVPEkH8RWCNtHdWwAaSBZ"
              },
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "children" => [
                          %{
                            "text" => ""
                          }
                        ],
                        "id" => "1761794908",
                        "type" => "p"
                      }
                    ],
                    "id" => "1049547669",
                    "type" => "content"
                  }
                ],
                "id" => "917336567",
                "type" => "alternative",
                "value" => "LrKibaPUfZdcfi5yi9YLc8"
              }
            ],
            "alternatives_id" => alt_group_revision_one.resource_id,
            "id" => "3353873708",
            "strategy" => "user_section_preference",
            "type" => "alternatives"
          }
        ]
      }

      # Create two new pages, both that reference alternative group one

      {:ok, %{revision: revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: content,
          title: "resource 1",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision)

      {:ok, %{revision: revision2}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: content,
          title: "resource 2",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision2)

      results =
        Publishing.find_alternatives_group_references_in_pages(
          alt_group_revision_one.resource_id,
          publication.id
        )

      assert length(results) == 2

      assert Enum.empty?(
               Publishing.find_alternatives_group_references_in_pages(
                 alt_group_revision_two.resource_id,
                 publication.id
               )
             )

      assert Enum.at(results, 0).title != Enum.at(results, 1).title

      assert Enum.at(results, 0).title == "resource 1" or
               Enum.at(results, 1).title == "resource 1"

      assert Enum.at(results, 0).title == "resource 2" or
               Enum.at(results, 1).title == "resource 2"
    end

    test "find_objective_attachments/2 returns the objective revisions", %{
      author: author,
      project: project,
      publication: publication,
      revision1: revision
    } do
      {:ok, %{revision: obj1}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)
      {:ok, %{revision: obj2}} = ObjectiveEditor.add_new(%{title: "two"}, author, project)
      {:ok, %{revision: obj3}} = ObjectiveEditor.add_new(%{title: "three"}, author, project)

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      activity1 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", []}],
          author,
          project,
          revision
        )

      activity2 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj1.resource_id]}],
          author,
          project,
          revision
        )

      activity3 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj2.resource_id]}],
          author,
          project,
          revision
        )

      activity4 =
        create_activity(
          [{"1", [obj2.resource_id]}, {"2", [obj3.resource_id]}],
          author,
          project,
          revision
        )

      update = %{
        "objectives" => %{"attached" => [obj1.resource_id]},
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => activity1.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "2",
              "activitySlug" => activity2.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "3",
              "activitySlug" => activity3.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "4",
              "activitySlug" => activity4.slug
            }
          ]
        }
      }

      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      results = Publishing.find_objective_attachments(obj1.resource_id, publication.id)

      assert length(results) == 5

      # activity 2 should appear twice since it has the objective attached in multiple parts
      assert Enum.filter(results, fn r -> r.resource_id == activity2.resource_id end) |> length ==
               2

      # the next two have it in only one part
      assert Enum.filter(results, fn r -> r.resource_id == activity1.resource_id end) |> length ==
               1

      assert Enum.filter(results, fn r -> r.resource_id == activity3.resource_id end) |> length ==
               1

      # this activity does not have this objective attached at all
      assert Enum.filter(results, fn r -> r.resource_id == activity4.resource_id end) |> length ==
               0

      # the page has it attached as well
      assert Enum.filter(results, fn r -> r.resource_id == revision.resource_id end) |> length ==
               1

      parent_pages = Publishing.determine_parent_pages([activity4.resource_id], publication.id)
      assert Map.has_key?(parent_pages, activity4.resource_id)
    end

    test "find_attached_objectives/1 returns all the revisions with objectives attached for a publication",
         %{
           author: author,
           project: project,
           publication: publication,
           revision1: revision
         } do
      {:ok, %{revision: obj1}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)
      {:ok, %{revision: obj2}} = ObjectiveEditor.add_new(%{title: "two"}, author, project)
      {:ok, %{revision: obj3}} = ObjectiveEditor.add_new(%{title: "three"}, author, project)

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      activity1 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", []}],
          author,
          project,
          revision
        )

      activity2 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj1.resource_id]}],
          author,
          project,
          revision
        )

      activity3 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj2.resource_id]}],
          author,
          project,
          revision
        )

      activity4 =
        create_activity(
          [{"1", [obj2.resource_id]}, {"2", [obj3.resource_id]}],
          author,
          project,
          revision
        )

      update = %{
        "objectives" => %{"attached" => [obj1.resource_id]},
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => activity1.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "2",
              "activitySlug" => activity2.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "3",
              "activitySlug" => activity3.slug
            },
            %{
              "type" => "activity-reference",
              "id" => "4",
              "activitySlug" => activity4.slug
            }
          ]
        }
      }

      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      results = Publishing.find_attached_objectives(publication.id)

      assert length(results) == 8

      assert length(
               Enum.filter(results, fn res -> res.attached_objective == obj1.resource_id end)
             ) == 5

      assert length(
               Enum.filter(results, fn res -> res.attached_objective == obj2.resource_id end)
             ) == 2

      assert length(
               Enum.filter(results, fn res -> res.attached_objective == obj3.resource_id end)
             ) == 1

      assert length(
               Enum.filter(results, fn res ->
                 res.resource_type_id == ResourceType.id_for_page()
               end)
             ) == 1

      assert length(
               Enum.filter(results, fn res ->
                 res.resource_type_id == ResourceType.id_for_activity()
               end)
             ) == 7
    end
  end

  describe "project publishing" do
    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "publish_project/1 publishes the active unpublished publication and creates a new working unpublished publication for a project",
         %{publication: publication, project: project, author: author} do
      {:ok, %Publication{} = published} =
        Publishing.publish_project(project, "some changes", author.id)

      # original publication should now be published
      assert published.id == publication.id
      assert published.published != nil
    end

    test "publish_project/1 creates a new working unpublished publication for a project",
         %{publication: unpublished_publication, project: project, author: author} do
      {:ok, %Publication{} = published_publication} =
        Publishing.publish_project(project, "some changes", author.id)

      # The published publication should match the original unpublished publication
      assert unpublished_publication.id == published_publication.id

      # the unpublished publication for the project should now be a new different publication
      new_unpublished_publication = Publishing.project_working_publication(project.slug)
      assert new_unpublished_publication.id != unpublished_publication.id

      # mappings should be retained in the original published publication
      unpublished_mappings =
        Publishing.get_published_resources_by_publication(unpublished_publication.id)
        |> Enum.sort_by(& &1.id)

      published_mappings =
        Publishing.get_published_resources_by_publication(published_publication.id)
        |> Enum.sort_by(& &1.id)

      assert unpublished_mappings == published_mappings

      # mappings should now be replaced with new mappings in the new publication
      assert unpublished_mappings !=
               Publishing.get_published_resources_by_publication(new_unpublished_publication.id)
               |> Enum.sort_by(& &1.id)
    end

    test "publish_project/1 publishes all currently locked resources and any new edits to the locked resource result in creation of a new revision for both pages and activities",
         %{
           publication: original_unpublished_publication,
           project: project,
           author: author,
           revision1: original_revision
         } do
      # lock a page
      {:acquired} = PageEditor.acquire_lock(project.slug, original_revision.slug, author.email)

      # lock an activity
      {:ok, %{revision: obj}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)

      revision_with_activity =
        create_activity(
          [{"1", [obj.resource_id]}, {"1", []}],
          author,
          project,
          original_revision
        )

      {:acquired} =
        PageEditor.acquire_lock(project.slug, revision_with_activity.slug, author.email)

      # Publish the project
      {:ok, %Publication{} = published_publication} =
        Publishing.publish_project(project, "some changes", author.id)

      # publication should succeed even if a resource is "locked"
      new_unpublished_publication = Publishing.project_working_publication(project.slug)
      assert new_unpublished_publication.id != original_unpublished_publication.id

      # further edits to locked resources should occur in newly created revisions. The locks should not
      # need to be re-acquired through a page reload triggering `PageEditor.acquire_lock`
      # in order to be able to continue editing the new revisions.

      # Update a page
      page_content = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [%{"type" => "content", "children" => [%{"text" => "A paragraph."}]}]
        }
      }

      # The page should not be able to be edited without re-acquiring the lock
      {:error, {:lock_not_acquired, _}} =
        PageEditor.edit(project.slug, original_revision.slug, author.email, page_content)

      {:acquired} = PageEditor.acquire_lock(project.slug, original_revision.slug, author.email)

      {:ok, updated_page_revision} =
        PageEditor.edit(project.slug, original_revision.slug, author.email, page_content)

      # The updates should occur on the new revision
      assert original_revision.id != updated_page_revision.id
      assert updated_page_revision.content == page_content["content"]

      # But the updates should not be present in the recently-published revision
      published_resource =
        Publishing.get_published_resource!(
          published_publication.id,
          revision_with_activity.resource_id
        )

      published_revision = Resources.get_revision!(published_resource.revision_id)
      assert published_revision.content == revision_with_activity.content
    end

    test "publish_project/1 updates revision_part with published information", %{author: author} do
      %{activity: %{revision: revision}, project: project} = project_with_activity()

      Publishing.publish_project(project, "Some description", author.id)

      assert Repo.all(
               from pm in "revision_parts",
                 where: pm.revision_id == ^revision.id,
                 select: pm.grading_approach
             ) == ["manual"]
    end

    test "broadcasting the new publication works when publishing", %{
      project: project,
      author: author
    } do
      Oli.Authoring.Broadcaster.Subscriber.subscribe_to_new_publications(project.slug)
      {:ok, publication} = Publishing.publish_project(project, "some changes", author.id)
      {:messages, [{:new_publication, pub, project_slug}]} = Process.info(self(), :messages)
      assert pub.id == publication.id
      assert project.slug == project_slug
    end

    test "diff_publications/2 returns the changes between 2 publications",
         %{publication: publication, project: project, author: author, revision1: revision} do
      # create a few more resources
      {:ok, %{revision: r2_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 1",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      {:ok, %{revision: r3_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 2",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, r2_revision)
      Publishing.upsert_published_resource(publication, r3_revision)

      # create first publication
      {:ok, %Publication{} = p1} = Publishing.publish_project(project, "some changes", author.id)

      # make some edits
      content = %{
        "version" => "0.1.0",
        "model" => [%{"type" => "content", "children" => [%{"text" => "A paragraph."}]}]
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      {:ok, _updated_revision} =
        PageEditor.edit(project.slug, revision.slug, author.email, %{content: content})

      # add another resource
      {:ok, %{revision: r4_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 3",
          resource_type_id: ResourceType.id_for_page(),
          author_id: author.id
        })

      p2 = Publishing.project_working_publication(project.slug)
      Publishing.upsert_published_resource(p2, r4_revision)

      # delete a resource
      PageEditor.acquire_lock(project.slug, r3_revision.slug, author.email)

      {:ok, _updated_revision} =
        PageEditor.edit(project.slug, r3_revision.slug, author.email, %{deleted: true})

      # generate diff
      %PublicationDiff{
        classification: classification,
        edition: edition,
        major: major,
        minor: minor,
        all_links: [],
        changes: diff
      } = Publishing.diff_publications(p1, p2)

      assert classification == :minor
      assert {edition, major, minor} == {0, 1, 1}
      assert Map.keys(diff) |> Enum.count() == 3
      assert {:changed, _} = diff[revision.resource_id]
      assert {:deleted, _} = diff[r3_revision.resource_id]
      assert {:added, _} = diff[r4_revision.resource_id]
    end

    test "available_publications/2 returns the publications",
         %{
           project: project,
           author2: author2,
           institution: institution
         } do
      {:ok, author3} =
        Author.noauth_changeset(%Author{}, %{
          email: "test33@test.com",
          given_name: "First",
          family_name: "Last",
          provider: "foo",
          system_role_id: SystemRole.role_id().author
        })
        |> Repo.insert()

      # create first publication
      {:ok, _} = Publishing.publish_project(project, "some changes", author2.id)

      second = Oli.Seeder.another_project(author2, institution, "second one")
      {:ok, _} = Publishing.publish_project(second.project, "some changes", author2.id)
      {:ok, _} = Publishing.publish_project(second.project, "some changes", author2.id)

      # by default, these projects are set to "private"
      assert Publishing.available_publications(nil, nil) |> length == 0
      assert Publishing.available_publications(author2, nil) |> length == 2
      assert Publishing.available_publications(author3, nil) |> length == 0

      # setting them to global
      {:ok, project} = Course.update_project(project, %{visibility: :global})
      Course.update_project(second.project, %{visibility: :global})

      assert Publishing.available_publications(nil, nil) |> length == 2
      assert Publishing.available_publications(author2, nil) |> length == 2
      assert Publishing.available_publications(author3, nil) |> length == 2

      # setting one to specific authors
      {:ok, project} = Course.update_project(project, %{visibility: :authors})
      Course.update_project(second.project, %{visibility: :selected})
      Publishing.insert_visibility(%{project_id: second.project.id, author_id: author3.id})
      assert Publishing.available_publications(author3, nil) |> length == 1

      # setting one to specific author and other to specific institution
      Course.update_project(project, %{visibility: :selected})
      Publishing.insert_visibility(%{project_id: project.id, institution_id: institution.id})
      assert Publishing.available_publications(author3, institution) |> length == 2
      assert Publishing.available_publications(author2, institution) |> length == 2
    end

    test "get_published_resources_by_publication/2 returns all the published resources of a given publication",
         %{publication: publication} do
      # mappings should be retained in the original published publication
      mappings = Publishing.get_published_resources_by_publication(publication.id)

      assert Enum.count(mappings) == 3
      assert Enum.all?(mappings, &(&1.publication.id == publication.id))
    end

    test "get_published_resources_by_publication/2 only preloads the given assocations",
         %{publication: publication} do
      # mappings should be retained in the original published publication
      mappings =
        Publishing.get_published_resources_by_publication(publication.id, preload: [:resource])

      assert Enum.all?(mappings, &Ecto.assoc_loaded?(&1.resource))
      refute Enum.all?(mappings, &Ecto.assoc_loaded?(&1.publication))
      refute Enum.all?(mappings, &Ecto.assoc_loaded?(&1.revision))
    end
  end

  describe "publishing retrieve visible publications" do
    test "retrieve_visible_publications/2 returns empty when there are no publications for existing projects" do
      user = insert(:user)
      institution = insert(:institution)
      insert(:project)

      assert [] == Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns global publications when user can access (no communities)" do
      user = insert(:user)
      institution = insert(:institution)
      %Publication{id: publication_id} = insert(:publication)

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns publications created by its linked author" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :authors, authors: [user.author])
      %Publication{id: publication_id} = insert(:publication, %{project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns publications associated to its linked author" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :selected)

      insert(:project_author_visibility, %{
        project_id: project.id,
        author_id: user.author.id
      })

      %Publication{id: publication_id} = insert(:publication, %{project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns publications associated to its institution" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :selected)

      insert(:project_institution_visibility, %{
        project_id: project.id,
        institution_id: institution.id
      })

      %Publication{id: publication_id} = insert(:publication, %{project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns empty because user's community doesn't allow global" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      insert(:community_member_account, %{user: user, community: community})

      # global project
      project = insert(:project)
      insert(:publication, %{project: project})

      assert [] = Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns global publications because some user's community allows it" do
      user = insert(:user)
      institution = insert(:institution)
      community_a = insert(:community)
      community_b = insert(:community, %{global_access: false})
      insert(:community_member_account, %{user: user, community: community_a})
      insert(:community_member_account, %{user: user, community: community_b})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns user's communities publications" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community)
      insert(:community_member_account, %{user: user, community: community})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      insert(:community_visibility, %{community: community, project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end

    test "retrieve_visible_publications/2 returns institutions's communities publications" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      insert(:community_institution, %{institution: institution, community: community})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      insert(:community_visibility, %{community: community, project: project})

      assert [%Publication{id: ^publication_id}] =
               Publishing.retrieve_visible_publications(user, institution)
    end
  end

  describe "publishing retrieve visible sources (publications and products)" do
    test "retrieve_visible_sources/2 returns empty when there are no publications/products for existing projects" do
      user = insert(:user)
      institution = insert(:institution)
      insert(:project)

      assert [] == Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns global publications/products when user can access (no communities)" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      assert [
               %Publication{id: ^publication_id},
               %Section{id: ^product_id}
             ] = Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns publications/products created by its linked author" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :authors, authors: [user.author])
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns publications/products associated to its linked author" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :selected)

      insert(:project_author_visibility, %{
        project_id: project.id,
        author_id: user.author.id
      })

      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns publications/products associated to its institution" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, visibility: :selected)

      insert(:project_institution_visibility, %{
        project_id: project.id,
        institution_id: institution.id
      })

      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns empty because user's community doesn't allow global" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      insert(:community_member_account, %{user: user, community: community})

      # global project
      project = insert(:project)
      insert(:publication, %{project: project})
      insert(:section, %{base_project: project})

      assert [] = Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns global publications/products because some user's community allows it" do
      user = insert(:user)
      institution = insert(:institution)
      community_a = insert(:community)
      community_b = insert(:community, %{global_access: false})
      insert(:community_member_account, %{user: user, community: community_a})
      insert(:community_member_account, %{user: user, community: community_b})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns user's communities publications/products" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community)
      insert(:community_member_account, %{user: user, community: community})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = insert(:section, %{base_project: project})

      insert(:community_visibility, %{community: community, project: project})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 returns institutions's communities publications/products" do
      user = insert(:user)
      institution = insert(:institution)
      community = insert(:community, %{global_access: false})
      insert(:community_institution, %{institution: institution, community: community})

      # global project
      project = insert(:project)
      %Publication{id: publication_id} = insert(:publication, %{project: project})
      %Section{id: product_id} = section = insert(:section, %{base_project: project})

      insert(:community_project_visibility, %{community: community, project: project})
      insert(:community_product_visibility, %{community: community, section: section})

      assert [%Publication{id: ^publication_id}, %Section{id: ^product_id}] =
               Publishing.retrieve_visible_sources(user, institution)
    end

    test "retrieve_visible_sources/2 does not return deleted products/projects" do
      user = insert(:user)
      institution = insert(:institution)
      project = insert(:project, status: :deleted)
      insert(:publication, %{project: project})
      insert(:section, %{base_project: project, status: :deleted})

      assert [] == Publishing.retrieve_visible_sources(user, institution)
    end
  end

  defp project_with_activity() do
    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "gradingApproach" => "manual",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {b}",
                "score" => 11,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {c}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    Oli.Seeder.base_project_with_resource2()
    |> Oli.Seeder.create_section()
    |> Oli.Seeder.add_user(%{}, :user1)
    |> Oli.Seeder.add_user(%{}, :user2)
    |> Oli.Seeder.add_activity(
      %{
        title: "Some activity",
        activity_type_id: Activities.get_registration_by_slug("oli_short_answer").id,
        content: content
      },
      :publication,
      :project,
      :author,
      :activity
    )
    |> Oli.Seeder.add_page(%{graded: true}, :graded_page)
    |> Oli.Seeder.create_section_resources()
  end

  describe "automatic update push for products and sections" do
    setup do
      seeds =
        %{}
        |> Seeder.Project.create_author(author_tag: :author)
        |> Seeder.Project.create_sample_project(
          ref(:author),
          project_tag: :proj,
          publication_tag: :pub,
          curriculum_revision_tag: :curriculum,
          unscored_page1_tag: :unscored_page1,
          unscored_page1_activity_tag: :unscored_page1_activity,
          scored_page2_tag: :scored_page2,
          scored_page2_activity_tag: :scored_page2_activity
        )
        |> Seeder.Project.ensure_published(ref(:pub))
        |> Seeder.Project.create_product("Product 1", ref(:proj), product_tag: :product1)
        |> Seeder.Project.create_product("Product 2", ref(:proj), product_tag: :product2)
        |> Seeder.Project.create_product("Product 3", ref(:proj), product_tag: :product3)
        |> Seeder.Section.create_section(
          ref(:proj),
          ref(:pub),
          nil,
          %{},
          section_tag: :section1
        )
        |> Seeder.Section.create_section(
          ref(:proj),
          ref(:pub),
          nil,
          %{},
          section_tag: :section2
        )
        |> Seeder.Project.resolve(ref(:proj), ref(:curriculum), revision_tag: :curriculum)
        |> Seeder.Project.create_container(
          ref(:author),
          ref(:proj),
          ref(:curriculum),
          %{
            title: "Unit 2"
          },
          revision_tag: :unit2
        )
        |> Seeder.Project.create_page(
          ref(:author),
          ref(:proj),
          ref(:unit2),
          %{
            title: "Page added after initial publish",
            content: %{
              "model" => [
                %{
                  "type" => "p",
                  "children" => [
                    %{"text" => "this page was added after initial publish"}
                  ]
                }
              ]
            },
            graded: false
          },
          revision_tag: :unscored_page1
        )

      working_publication = Publishing.project_working_publication(seeds.proj.slug)

      seeds
      |> Seeder.Project.ensure_published(working_publication, publication_tag: :pub2)
    end

    test "fetch_products_and_sections_eligible_for_update returns product and sections eligible for update",
         %{
           proj: project,
           pub: pub,
           product1: product1,
           product2: product2,
           product3: product3,
           section1: section1,
           section2: section2
         } do
      result =
        Publishing.fetch_products_and_sections_eligible_for_update(project.id, pub.id)
        |> Enum.map(fn %{section: s, current_publication_id: pub_id} ->
          {s.id, s.title, s.end_date, pub_id}
        end)

      assert result == [
               {product1.id, "Product 1", nil, pub.id},
               {product2.id, "Product 2", nil, pub.id},
               {product3.id, "Product 3", nil, pub.id},
               {section1.id, "Example Section", nil, pub.id},
               {section2.id, "Example Section", nil, pub.id}
             ]
    end

    test "push_publication_update_to_sections creates update oban jobs", %{
      proj: project,
      pub: pub,
      pub2: pub2,
      product1: product1,
      product2: product2,
      product3: product3,
      section1: section1,
      section2: section2
    } do
      Publishing.push_publication_update_to_sections(project, pub, pub2)

      result_jobs =
        Ecto.Query.from(j in Oban.Job,
          where: j.worker == "Oli.Delivery.Updates.Worker",
          order_by: j.id
        )
        |> Repo.all()

      assert Enum.count(result_jobs) == 5

      assert Enum.map(result_jobs, fn %{args: args} -> args end) == [
               %{
                 "section_slug" => product1.slug,
                 "publication_id" => pub2.id
               },
               %{
                 "section_slug" => product2.slug,
                 "publication_id" => pub2.id
               },
               %{
                 "section_slug" => product3.slug,
                 "publication_id" => pub2.id
               },
               %{
                 "section_slug" => section1.slug,
                 "publication_id" => pub2.id
               },
               %{
                 "section_slug" => section2.slug,
                 "publication_id" => pub2.id
               }
             ]
    end
  end
end
