defmodule Oli.Authoring.Editing.ContainerEditorTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Locks

  describe "container editing" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "list_all_container_children/2 returns the pages", %{
      project: project,
      revision2: revision2,
      revision1: revision1,
      container: %{revision: container}
    } do
      pages = ContainerEditor.list_all_container_children(container, project)

      assert length(pages) == 2
      assert hd(pages).id == revision1.id
      assert hd(tl(pages)).id == revision2.id
    end

    test "add_new/4 creates a new page and attaches it to the root", %{
      author: author,
      project: project
    } do
      page = %{
        objectives: %{"attached" => []},
        children: [],
        content: %{"model" => []},
        title: "New Page",
        graded: true,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      }

      container = AuthoringResolver.root_container(project.slug)
      {:ok, revision} = ContainerEditor.add_new(container, page, author, project)

      container = AuthoringResolver.root_container(project.slug)
      assert revision.title == "New Page"

      # Ensure that the edit has inserted the new page reference
      # first in the collection
      assert length(container.children) == 3
      assert Enum.find_index(container.children, fn c -> revision.resource_id == c end) == 2
    end

    test "remove_child/4 removes correctly", %{
      author: author,
      project: project,
      revision1: revision1
    } do
      container = AuthoringResolver.root_container(project.slug)
      {:ok, _} = ContainerEditor.remove_child(container, project, author, revision1.slug)

      # Verify we have removed it from the container
      container = AuthoringResolver.root_container(project.slug)
      assert length(container.children) == 1
      assert Enum.find_index(container.children, fn c -> revision1.resource_id == c end) == nil

      # Verify that we have marked the resource as being deleted
      updated = AuthoringResolver.from_resource_id(project.slug, revision1.resource_id)
      assert updated.deleted == true
    end

    test "remove_child/4 fails when target resource is locked", %{
      publication: publication,
      author2: author2,
      author: author,
      project: project,
      page1: page1,
      revision1: revision1
    } do
      container = AuthoringResolver.root_container(project.slug)
      {:acquired} = Locks.acquire(project.slug, publication.id, page1.id, author2.id)

      # Verify that the remove failed due to the lock
      case ContainerEditor.remove_child(container, project, author, revision1.slug) do
        {:ok, _} -> assert false
        {:error, {:lock_not_acquired, _}} -> assert true
      end
    end

    test "remove_child/4 succeeds when target resource is locked by same user", %{
      publication: publication,
      author: author,
      project: project,
      page1: page1,
      revision1: revision1
    } do
      container = AuthoringResolver.root_container(project.slug)
      {:acquired} = Locks.acquire(project.slug, publication.id, page1.id, author.id)

      case ContainerEditor.remove_child(container, project, author, revision1.slug) do
        {:ok, _} -> assert true
        {:error, {:lock_not_acquired, _}} -> assert false
      end
    end

    test "reorder_child/4 reorders correctly", %{author: author, project: project} do
      page = %{
        objectives: %{"attached" => []},
        children: [],
        content: %{"model" => []},
        title: "New Page",
        graded: true,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      }

      container = AuthoringResolver.root_container(project.slug)
      {:ok, revision} = ContainerEditor.add_new(container, page, author, project)

      # we now have three pages to reorder with:
      {:ok, _} = ContainerEditor.reorder_child(container, project, author, revision.slug, 2)
      container = AuthoringResolver.root_container(project.slug)
      assert length(container.children) == 3
      assert Enum.find_index(container.children, fn c -> revision.resource_id == c end) == 2

      {:ok, _} = ContainerEditor.reorder_child(container, project, author, revision.slug, 3)
      container = AuthoringResolver.root_container(project.slug)
      assert length(container.children) == 3
      assert Enum.find_index(container.children, fn c -> revision.resource_id == c end) == 2

      {:ok, _} = ContainerEditor.reorder_child(container, project, author, revision.slug, 100)
      container = AuthoringResolver.root_container(project.slug)
      assert length(container.children) == 3
      assert Enum.find_index(container.children, fn c -> revision.resource_id == c end) == 2

      {:ok, _} = ContainerEditor.reorder_child(container, project, author, revision.slug, 0)
      container = AuthoringResolver.root_container(project.slug)
      assert length(container.children) == 3
      assert Enum.find_index(container.children, fn c -> revision.resource_id == c end) == 0
    end
  end

  describe "nested container editing" do
    setup do
      Seeder.base_project_with_resource3()
    end

    test "move_to/4 moves a curriculum item from one container to another", %{
      author: author,
      project: project,
      container: %{revision: root_container},
      revision1: page1_revision,
      unit1_container: %{revision: unit1_container}
    } do
      assert length(root_container.children) == 3

      {:ok, _} =
        ContainerEditor.move_to(page1_revision, root_container, unit1_container, author, project)

      root_container =
        AuthoringResolver.from_resource_id(project.slug, root_container.resource_id)

      unit1_container =
        AuthoringResolver.from_resource_id(project.slug, unit1_container.resource_id)

      # Ensure that the edit has inserted the moved page into unit1 container
      assert length(root_container.children) == 2
      assert length(unit1_container.children) == 3

      assert Enum.find_index(unit1_container.children, fn c -> page1_revision.resource_id == c end) ==
               2
    end
  end

  describe "page duplication" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective 1", :obj1)
    end

    test "duplicate_page/1 duplicates a page correctly", %{
      author: author,
      project: project,
      obj1: obj1
    } do
      embeded_activity_content = %{
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
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      {:ok, {activity_revision, _}} =
        ActivityEditor.create(
          project.slug,
          "oli_short_answer",
          author,
          embeded_activity_content,
          [obj1.resource.id],
          "embedded",
          "An embedded activity"
        )

      {:ok, {activity_revision2, _}} =
        ActivityEditor.create(
          project.slug,
          "oli_short_answer",
          author,
          embeded_activity_content,
          [obj1.resource.id],
          "embedded",
          "An embedded activity"
        )

      page = %{
        objectives: %{"attached" => [obj1.resource.id]},
        children: [],
        content: %{
          "model" => [
            %{
              "id" => UUID.uuid4(),
              "type" => "content",
              "purpose" => "none",
              "children" => [
                %{
                  "id" => UUID.uuid4(),
                  "type" => "p",
                  "children" => [%{"text" => "Here's some test content"}]
                }
              ]
            },
            # Embedded activity 1
            %{
              "id" => UUID.uuid4(),
              "type" => "activity-reference",
              "children" => [],
              "activity_id" => activity_revision.resource_id
            },
            %{
              "type" => "group",
              "id" => UUID.uuid4(),
              "children" => [
                # Embedded activity 2, a nested activity
                %{
                  "id" => UUID.uuid4(),
                  "type" => "activity-reference",
                  "children" => [],
                  "activity_id" => activity_revision2.resource_id
                }
              ]
            }
          ]
        },
        title: "New Page",
        graded: true,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      }

      root_container = AuthoringResolver.root_container(project.slug)
      {:ok, page_revision} = ContainerEditor.add_new(root_container, page, author, project)

      assert page_revision.title == "New Page"

      {:ok, duplicated_page_revision} =
        ContainerEditor.duplicate_page(root_container, page_revision.id, author, project)

      assert duplicated_page_revision.title == "New Page (copy)"

      assert length(duplicated_page_revision.content["model"]) ==
               length(page_revision.content["model"])

      assert duplicated_page_revision.objectives == page.objectives

      # Verify that it deep copied BOTH activities, the top level and the nested activity

      # Top level
      activity_reference = duplicated_page_revision.content["model"] |> Enum.at(1)
      refute activity_reference["activity_id"] == activity_revision.resource_id

      created_activity =
        Repo.get_by(Oli.Resources.Revision, %{resource_id: activity_reference["activity_id"]})

      assert created_activity.objectives["1"] == activity_revision.objectives["1"]

      # The nested activity
      activity_reference2 =
        duplicated_page_revision.content["model"]
        |> Enum.at(2)
        |> Map.get("children")
        |> Enum.at(0)

      refute activity_reference2["activity_id"] == activity_revision2.resource_id

      created_activity2 =
        Repo.get_by(Oli.Resources.Revision, %{resource_id: activity_reference2["activity_id"]})

      assert created_activity2.objectives["1"] == activity_revision2.objectives["1"]
    end
  end
end
