defmodule Oli.PublishingTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Locks
  alias Oli.Accounts.{SystemRole, Author}
  alias Oli.Delivery.Sections.Section

  def create_activity(parts, author, project, page_revision, obj_resource_id) do
    # Create a two part activity where each part is tied to one of the objectives above

    objectives =
      Enum.reduce(parts, %{}, fn {part_id, slugs}, m ->
        Map.put(m, part_id, slugs)
      end)

    parts = Enum.map(parts, fn {part_id, _} -> part_id end)
    content = %{"content" => %{"authoring" => %{"parts" => parts}}}

    {:ok, {revision, _}} =
      ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

    # attach just one activity
    update = %{
      "objectives" => %{"attached" => [obj_resource_id]},
      "content" => %{
        "model" => [
          %{
            "type" => "activity-reference",
            "id" => 1,
            "activitySlug" => revision.slug,
            "purpose" => "none"
          }
        ]
      }
    }

    PageEditor.acquire_lock(project.slug, page_revision.slug, author.email)
    assert {:ok, _} = PageEditor.edit(project.slug, page_revision.slug, author.email, update)

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

  describe "retrieve_lock_info" do
    setup do
      Seeder.base_project_with_resource2()
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
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("one", :one)
      |> Seeder.add_objective("two", :two)
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
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision)

      {:ok, %{revision: revision2}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: content,
          title: "resource 2",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, revision2)

      results = Publishing.find_objective_in_selections(one.resource.id, publication.id)
      assert length(results) == 2
      assert length(Publishing.find_objective_in_selections(two.resource.id, publication.id)) == 0

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

      activity1 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", []}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity2 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj1.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity3 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj2.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity4 =
        create_activity(
          [{"1", [obj2.resource_id]}, {"2", [obj3.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      results = Publishing.find_objective_attachments(obj1.resource_id, publication.id)

      assert length(results) == 5

      # activity 2 should appear twice since it has the objective attached in multiple parts
      assert Enum.filter(results, fn r -> r.id == activity2.id end) |> length == 2

      # the next two have it in only one part
      assert Enum.filter(results, fn r -> r.id == activity1.id end) |> length == 1
      assert Enum.filter(results, fn r -> r.id == activity3.id end) |> length == 1

      # this activity does not have this objective attached at all
      assert Enum.filter(results, fn r -> r.id == activity4.id end) |> length == 0

      # the page has it attached as well
      assert Enum.filter(results, fn r -> r.resource_id == revision.resource_id end) |> length ==
               1

      parent_pages = Publishing.determine_parent_pages([activity4.resource_id], publication.id)
      assert Map.has_key?(parent_pages, activity4.resource_id)
    end
  end

  describe "project publishing" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "publish_project/1 publishes the active unpublished publication and creates a new working unpublished publication for a project",
         %{publication: publication, project: project} do
      {:ok, %Publication{} = published} = Publishing.publish_project(project, "some changes")

      # original publication should now be published
      assert published.id == publication.id
      assert published.published != nil
    end

    test "publish_project/1 creates a new working unpublished publication for a project",
         %{publication: unpublished_publication, project: project} do
      {:ok, %Publication{} = published_publication} =
        Publishing.publish_project(project, "some changes")

      # The published publication should match the original unpublished publication
      assert unpublished_publication.id == published_publication.id

      # the unpublished publication for the project should now be a new different publication
      new_unpublished_publication = Publishing.project_working_publication(project.slug)
      assert new_unpublished_publication.id != unpublished_publication.id

      # mappings should be retained in the original published publication
      unpublished_mappings =
        Publishing.get_published_resources_by_publication(unpublished_publication.id)

      published_mappings =
        Publishing.get_published_resources_by_publication(published_publication.id)

      assert unpublished_mappings == published_mappings

      # mappings should now be replaced with new mappings in the new publication
      assert unpublished_mappings !=
               Publishing.get_published_resources_by_publication(new_unpublished_publication.id)
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
          original_revision,
          obj.resource_id
        )

      {:acquired} =
        PageEditor.acquire_lock(project.slug, revision_with_activity.slug, author.email)

      # Publish the project
      {:ok, %Publication{} = published_publication} =
        Publishing.publish_project(project, "some changes")

      # publication should succeed even if a resource is "locked"
      new_unpublished_publication = Publishing.project_working_publication(project.slug)
      assert new_unpublished_publication.id != original_unpublished_publication.id

      # further edits to locked resources should occur in newly created revisions. The locks should not
      # need to be re-acquired through a page reload triggering `PageEditor.acquire_lock`
      # in order to be able to continue editing the new revisions.

      # Update a page
      page_content = %{
        "content" => %{
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

    test "broadcasting the new publication works when publishing", %{project: project} do
      Oli.Authoring.Broadcaster.Subscriber.subscribe_to_new_publications(project.slug)
      {:ok, publication} = Publishing.publish_project(project, "some changes")
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
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      {:ok, %{revision: r3_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 2",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, r2_revision)
      Publishing.upsert_published_resource(publication, r3_revision)

      # create first publication
      {:ok, %Publication{} = p1} = Publishing.publish_project(project, "some changes")

      # make some edits
      content = %{
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
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      p2 = Publishing.project_working_publication(project.slug)
      Publishing.upsert_published_resource(p2, r4_revision)

      # delete a resource
      PageEditor.acquire_lock(project.slug, r3_revision.slug, author.email)

      {:ok, _updated_revision} =
        PageEditor.edit(project.slug, r3_revision.slug, author.email, %{deleted: true})

      # generate diff
      {version_info, diff} = Publishing.diff_publications(p1, p2)
      assert version_info == {:minor, {0, 1, 1}}
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
      {:ok, _} = Publishing.publish_project(project, "some changes")

      second = Oli.Seeder.another_project(author2, institution, "second one")
      {:ok, _} = Publishing.publish_project(second.project, "some changes")
      {:ok, _} = Publishing.publish_project(second.project, "some changes")

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
  end
end
