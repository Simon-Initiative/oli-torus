defmodule Oli.Authoring.Editing.ObjectiveEditorTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.{ActivityEditor, ObjectiveEditor, PageEditor}
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision

  describe "objective editing" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.add_objective("sub objective 1", :subobjective12A)
        |> Seeder.add_objective("sub objective 2", :subobjective2B)
        |> Seeder.add_objective("sub objective 3", :subobjective3A)
        |> Seeder.add_objective_with_children("objective 1", [:subobjective12A], :objective1)
        |> Seeder.add_objective_with_children(
          "objective 2",
          [:subobjective12A, :subobjective2B],
          :objective2
        )
        |> Seeder.add_objective_with_children("objective 3", [:subobjective3A], :objective3)

      %{
        map: map,
        author: map.author,
        project: map.project,
        revision1: map.revision1
      }
    end

    test "delete/3 removes an objective", %{author: author, project: project} do
      {:ok, %{revision: parent}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)

      {:ok, _} = ObjectiveEditor.delete(parent.slug, author, project)

      updated_parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)

      assert updated_parent.deleted == true
    end

    test "delete/4 removes objectives from parent during deletion", %{
      author: author,
      project: project
    } do
      {:ok, %{revision: parent}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      {:ok, %{revision: child}} =
        ObjectiveEditor.add_new(%{title: "Sub Objective"}, author, project, parent.slug)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      assert parent.children == [child.resource_id]

      {:ok, _} = ObjectiveEditor.delete(child.slug, author, project, parent)

      updated_parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      updated_child = AuthoringResolver.from_resource_id(project.slug, child.resource_id)

      assert updated_child.deleted == true
      refute Enum.any?(updated_parent.children, fn id -> id == updated_child.resource_id end)
    end

    test "add_new/3 can add an objetive", %{author: author, project: project} do
      {:ok, %{revision: revision}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      assert revision.title == "Test Objective"
    end

    test "add_new/4 can add an objetive to a parent objective", %{
      author: author,
      project: project
    } do
      {:ok, %{revision: parent}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      {:ok, %{revision: child}} =
        ObjectiveEditor.add_new(%{title: "Sub Objective"}, author, project, parent.slug)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      assert parent.children == [child.resource_id]
    end

    test "edit/4 edits the title of an objective", %{author: author, project: project} do
      {:ok, %{revision: revision}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      {:ok, edited} = ObjectiveEditor.edit(revision.slug, %{title: "Edited"}, author, project)

      assert edited.title == "Edited"
      refute edited.id == revision.id
    end

    test "detach_objective/3 removes an objective from pages", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      objectives = %{"attached" => [objective.resource_id]}
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      {:ok, updated_revision} =
        PageEditor.edit(project.slug, revision.slug, author.email, %{"objectives" => objectives})

      PageEditor.release_lock(project.slug, revision.slug, author.email)

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_page =
        AuthoringResolver.from_resource_id(project.slug, updated_revision.resource_id)

      assert updated_page.objectives == %{"attached" => []}
    end

    test "detach_objective/3 does not remove when locked", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      objectives = %{"attached" => [objective.resource_id]}

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      {:ok, updated_revision} =
        PageEditor.edit(project.slug, revision.slug, author.email, %{"objectives" => objectives})

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_page =
        AuthoringResolver.from_resource_id(project.slug, updated_revision.resource_id)

      assert updated_page.objectives == %{"attached" => [objective.resource_id]}
    end

    test "detach_objective/3 removes an objective from an activity", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{"stem" => "one"}

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      update = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      attachment = %{
        "objectives" => %{"1" => [objective.resource_id]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      ActivityEditor.edit(
        project.slug,
        revision.resource_id,
        activity_id,
        author.email,
        attachment
      )

      PageEditor.release_lock(project.slug, revision.slug, author.email)

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert updated_activity.objectives == %{"1" => []}
    end

    test "detach_objective/3 removes an objective from a banked activity", %{
      author: author,
      project: project
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{"stem" => "one"}

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [], :banked)

      PageEditor.acquire_lock(project.slug, slug, author.email)

      attachment = %{
        "objectives" => %{"1" => [objective.resource_id]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      ActivityEditor.edit(
        project.slug,
        activity_id,
        activity_id,
        author.email,
        attachment
      )

      PageEditor.release_lock(project.slug, slug, author.email)

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert updated_activity.objectives == %{"1" => []}
    end

    test "detach_objective/3 does not remove an objective from a locked banked activity", %{
      author: author,
      project: project
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{"stem" => "one"}

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [], :banked)

      PageEditor.acquire_lock(project.slug, slug, author.email)

      attachment = %{
        "objectives" => %{"1" => [objective.resource_id]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      ActivityEditor.edit(
        project.slug,
        activity_id,
        activity_id,
        author.email,
        attachment
      )

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      refute updated_activity.objectives == %{"1" => []}
    end

    test "detach_objective/3 does not remove an objective from an activity that is locked", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{"stem" => "one"}

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      update = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      attachment = %{
        "objectives" => %{"1" => [objective.slug]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      ActivityEditor.edit(
        project.slug,
        revision.resource_id,
        activity_id,
        author.email,
        attachment
      )

      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      refute updated_activity.objectives == %{"1" => []}
    end

    test "add_new_parent_for_sub_objective/4", %{
      project: project,
      author: author,
      map: %{
        objective1: %{revision: %Revision{slug: objective1_slug, children: objective1_children}},
        subobjective3A: %{
          revision: %Revision{resource_id: subobjective3A_resource_id, slug: subobjective3A_slug}
        }
      }
    } do
      assert length(objective1_children) == 1
      refute Enum.member?(objective1_children, subobjective3A_resource_id)

      {:ok, %Revision{slug: slug, children: children}} =
        ObjectiveEditor.add_new_parent_for_sub_objective(
          subobjective3A_slug,
          objective1_slug,
          project.slug,
          author
        )

      assert slug == objective1_slug
      assert length(children) == 2
      assert Enum.member?(children, subobjective3A_resource_id)
    end

    test "remove_sub_objective_from_parent/4", %{
      project: project,
      author: author,
      map: %{
        objective1: %{
          revision: %Revision{slug: objective1_slug, children: objective1_children} = objective1
        },
        objective2: %{revision: %Revision{children: objective2_children}},
        subobjective12A: %{
          revision: %Revision{
            resource_id: subobjective12A_resource_id,
            slug: subobjective12A_slug
          }
        }
      }
    } do
      assert length(objective1_children) == 1
      assert Enum.member?(objective1_children, subobjective12A_resource_id)

      {:ok, %Revision{slug: slug, children: children}} =
        ObjectiveEditor.remove_sub_objective_from_parent(
          subobjective12A_slug,
          author,
          project,
          objective1
        )

      assert slug == objective1_slug
      assert length(children) == 0
      refute Enum.member?(children, subobjective12A_resource_id)
      assert Enum.member?(objective2_children, subobjective12A_resource_id)
    end

    test "detach_objective/3 preserves tags when removing an objective from a banked activity", %{
      author: author,
      project: project
    } do
      # Create an objective
      {:ok, %{revision: objective}} =
        ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # Create a banked activity with tags
      content = %{"stem" => "one"}
      tags = [1, 2, 3]

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(
          project.slug,
          "oli_multiple_choice",
          author,
          content,
          [],
          :banked,
          nil,
          %{},
          tags
        )

      # Verify the activity has tags
      initial_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert initial_activity.tags == tags

      # Attach the objective to the activity
      PageEditor.acquire_lock(project.slug, slug, author.email)

      attachment = %{
        "objectives" => %{"1" => [objective.resource_id]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      ActivityEditor.edit(
        project.slug,
        activity_id,
        activity_id,
        author.email,
        attachment
      )

      PageEditor.release_lock(project.slug, slug, author.email)

      # Verify objective was attached
      activity_with_objective = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert activity_with_objective.objectives == %{"1" => [objective.resource_id]}
      assert activity_with_objective.tags == tags

      # Detach the objective
      ObjectiveEditor.detach_objective(objective.resource_id, project, author)

      # Verify objective was removed but tags were preserved
      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert updated_activity.objectives == %{"1" => []}
      assert updated_activity.tags == tags
    end
  end
end
