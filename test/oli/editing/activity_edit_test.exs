defmodule Oli.ActivityEditingTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.{ResourceContext, ResourceEditor}
  alias Oli.Editing.ActivityEditor

  describe "activity editing" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "create/4 creates an activity revision", %{author: author, project: project } do

      content = %{ "stem" => "Hey there" }
      {:ok, revision} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content)
      assert revision.content == %{ "stem" => "Hey there" }
    end

    test "can create and attach an activity to a resource", %{author: author, project: project, revision: revision } do
      content = %{ "stem" => "Hey there" }
      {:ok, %{slug: slug, activity_id: activity_id}} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content)

      # Verify that we can issue a resource edit that attaches the activity
      update = %{ "content" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => slug, "purpose" => "none"}]}
      assert {:ok, updated_revision} =  ResourceEditor.edit(project.slug, revision.slug, author.email, update)

      # Verify that the slug was translated to the correct activity id
      activity_ref = hd(updated_revision.content)
      assert activity_id == Map.get(activity_ref, "activity_id")
      refute Map.has_key?(activity_ref, "activitySlug")


      # Now generate the resource editing context with this attached activity in place
      # so that we can verify that the activities, editorMap and content are all wired
      # together correctly
      {:ok, %ResourceContext{activities: activities, content: content, editorMap: editorMap}} = ResourceEditor.create_context(project.slug, updated_revision.slug, author)

      activity_ref = hd(content)

      # verifies that the content entry has an activitySlug that references an activity map entry
      activity_slug = Map.get(activity_ref, "activitySlug")
      assert Map.has_key?(activities, activity_slug)

      # and that activity map entry has a type slug that references an editor map entry
      %{typeSlug: typeSlug} = Map.get(activities, activity_slug)
      assert Map.has_key?(editorMap, typeSlug)

    end

    test "attaching an unknown activity to a resource fails", %{author: author, project: project, revision: revision } do

      update = %{ "content" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => "missing", "purpose" => "none"}]}
      assert {:error, :not_found} =  ResourceEditor.edit(project.slug, revision.slug, author.email, update)

    end

  end

end
