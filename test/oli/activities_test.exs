defmodule Oli.ActivitiesTest do
  use Oli.DataCase
  import ExUnit.Assertions
  alias Oli.Activities

  setup [:author_project_fixture]

  describe "add activity to project" do
    test "adding a custom registered activity to a project", %{project: project} do
      custom_activity = Activities.get_registration_by_slug("oli_image_coding")

      Activities.enable_activity_in_project(project.slug, custom_activity.slug)
      project_activities = Activities.activities_for_project(project)

      assert project_activities
             |> Enum.filter(
               &match?(
                 %{
                   id: _,
                   authoring_element: "oli-image-coding-authoring",
                   delivery_element: "oli-image-coding-delivery",
                   enabled: true,
                   global: false,
                   slug: "oli_image_coding",
                   title: "Image Coding"
                 },
                 &1
               )
             )
             |> length == 1
    end

    test "removing a custom registered activity from a project", %{project: project} do
      custom_activity = Activities.get_registration_by_slug("oli_image_coding")

      Activities.enable_activity_in_project(project.slug, custom_activity.slug)
      Activities.disable_activity_in_project(project.slug, custom_activity.slug)
      project_activities = Activities.activities_for_project(project)

      assert project_activities
             |> Enum.filter(
               &match?(
                 %{
                   id: _,
                   authoring_element: "oli-image-coding-authoring",
                   delivery_element: "oli-image-coding-delivery",
                   enabled: false,
                   global: false,
                   slug: "oli_image_coding",
                   title: "Image Coding"
                 },
                 &1
               )
             )
             |> length == 1
    end

    test "default editor menu should not include custom activity", %{project: project} do
      editor_menu_items = Activities.create_registered_activity_map(project.slug)

      image_coding = Map.get(editor_menu_items, "oli_image_coding")
      assert !image_coding.globallyAvailable and !image_coding.enabledForProject
    end

    test "editor menu with custom activity included", %{project: project} do
      custom_activity = Activities.get_registration_by_slug("oli_image_coding")

      Activities.enable_activity_in_project(project.slug, custom_activity.slug)
      editor_menu_items = Activities.create_registered_activity_map(project.slug)

      image_coding = Map.get(editor_menu_items, "oli_image_coding")
      assert !image_coding.globallyAvailable and image_coding.enabledForProject
    end
  end
end
