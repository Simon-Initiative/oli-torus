defmodule Oli.ActivitiesTest do
  use Oli.DataCase
  import ExUnit.Assertions
  alias Oli.Activities
  alias Oli.Lti.PlatformExternalTools

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

  describe "list activities" do
    test "list_activity_registrations_with_deployment_id/0 works correctly" do
      # register a new lti external tool activity
      params = %{
        "name" => "External Tool Test 1",
        "description" => "External Tool Description",
        "client_id" => "new_tool_client_id_1",
        "target_link_uri" => "https://example.com/launch",
        "login_url" => "https://example.com/login",
        "keyset_url" => "https://example.com/jwks",
        "redirect_uris" => "https://example.com/redirect",
        "custom_params" => "param1=value1&param2=value2"
      }

      {:ok, {_platform_instance, activity_registration, deployment}} =
        PlatformExternalTools.register_lti_external_tool_activity(params)

      # get activity registrations with deployment id
      activities = Activities.list_activity_registrations_with_deployment_id()

      # assert that all activities have the :deployment_id field
      assert Enum.all?(activities, fn activity ->
               Map.has_key?(activity, :deployment_id)
             end)

      # assert that the lti external tool activity is included in the list with their deployment id
      new_activity_registered =
        Enum.find(activities, fn activity ->
          activity.id == activity_registration.id
        end)

      assert new_activity_registered.deployment_id == deployment.deployment_id
    end
  end
end
