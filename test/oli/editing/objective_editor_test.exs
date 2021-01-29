defmodule Oli.Authoring.Editing.ObjectiveEditorTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Publishing.AuthoringResolver

  describe "objective editing" do

    setup do
      Seeder.base_project_with_resource2()
    end


    test "delete/3 removes an objective", %{author: author, project: project } do

      {:ok, %{revision: parent}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)

      {:ok, _} = ObjectiveEditor.delete(parent.slug, author, project)

      updated_parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)

      assert updated_parent.deleted == true

    end

    test "delete/4 removes objectives from parent during deletion", %{author: author, project: project } do

      {:ok, %{revision: parent}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)
      {:ok, %{revision: child}} = ObjectiveEditor.add_new(%{title: "Sub Objective"}, author, project, parent.slug)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      assert parent.children == [child.resource_id]

      {:ok, _} = ObjectiveEditor.delete(child.slug, author, project, parent)

      updated_parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      updated_child = AuthoringResolver.from_resource_id(project.slug, child.resource_id)

      assert updated_child.deleted == true
      refute Enum.any?(updated_parent.children, fn id -> id == updated_child.resource_id end)

    end

    test "add_new/3 can add an objetive", %{author: author, project: project } do

      {:ok, %{revision: revision}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)
      assert revision.title == "Test Objective"
    end

    test "add_new/4 can add an objetive to a parent objective", %{author: author, project: project } do

      {:ok, %{revision: parent}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)
      {:ok, %{revision: child}} = ObjectiveEditor.add_new(%{title: "Sub Objective"}, author, project, parent.slug)

      parent = AuthoringResolver.from_resource_id(project.slug, parent.resource_id)
      assert parent.children == [child.resource_id]

    end

    test "edit/4 edits the title of an objective", %{author: author, project: project } do

      {:ok, %{revision: revision}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)
      {:ok, edited} = ObjectiveEditor.edit(revision.slug, %{title: "Edited"}, author, project)

      assert edited.title == "Edited"
      refute edited.id == revision.id

    end

    test "detach_objective/3 removes an objective from pages", %{author: author, project: project, revision1: revision} do

      {:ok, %{revision: objective}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      objectives = %{"attached" => [objective.slug] }
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      {:ok, updated_revision} = PageEditor.edit(project.slug, revision.slug, author.email, %{ "objectives" => objectives })
      PageEditor.release_lock(project.slug, revision.slug, author.email)

      ObjectiveEditor.detach_objective(objective.slug, project, author)

      updated_page = AuthoringResolver.from_resource_id(project.slug, updated_revision.resource_id)
      assert updated_page.objectives == %{"attached" => []}

    end

    test "detach_objective/3 does not remove when locked", %{author: author, project: project, revision1: revision} do

      {:ok, %{revision: objective}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      objectives = %{"attached" => [objective.slug] }
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      {:ok, updated_revision} = PageEditor.edit(project.slug, revision.slug, author.email, %{ "objectives" => objectives })

      ObjectiveEditor.detach_objective(objective.slug, project, author)

      updated_page = AuthoringResolver.from_resource_id(project.slug, updated_revision.resource_id)
      assert updated_page.objectives == %{"attached" => [objective.resource_id]}

    end

    test "detach_objective/3 removes an objective from an activity", %{author: author, project: project, revision1: revision} do

      {:ok, %{revision: objective}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{ "stem" => "one" }
      {:ok, {%{slug: slug, resource_id: activity_id}, _}} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      update = %{ "content" => %{ "model" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => slug, "purpose" => "none"}]}}
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)
      attachment = %{ "objectives" => %{ "1" => [ objective.slug ] },
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1" }]}}}

      ActivityEditor.edit(project.slug, revision.resource_id, activity_id, author.email, attachment)
      PageEditor.release_lock(project.slug, revision.slug, author.email)

      ObjectiveEditor.detach_objective(objective.slug, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert updated_activity.objectives == %{"1" => []}

    end

    test "detach_objective/3 does not remove an objective from an activity that is locked", %{author: author, project: project, revision1: revision} do

      {:ok, %{revision: objective}} = ObjectiveEditor.add_new(%{title: "Test Objective"}, author, project)

      # attach it to a page and release the lock
      content = %{ "stem" => "one" }
      {:ok, {%{slug: slug, resource_id: activity_id}, _}} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      update = %{ "content" => %{ "model" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => slug, "purpose" => "none"}]}}
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)
      attachment = %{ "objectives" => %{ "1" => [ objective.slug ] },
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1" }]}}}

      ActivityEditor.edit(project.slug, revision.resource_id, activity_id, author.email, attachment)
      ObjectiveEditor.detach_objective(objective.slug, project, author)

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity_id)
      refute updated_activity.objectives == %{"1" => []}

    end

  end

end
