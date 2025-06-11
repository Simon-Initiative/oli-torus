defmodule Oli.ActivitiesTest do
  use Oli.DataCase
  import ExUnit.Assertions
  import Oli.Factory
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

  describe "list_lti_activity_registrations/1" do
    setup do
      lti_activity1 =
        insert(:activity_registration, %{
          slug: "lti_activity_1",
          title: "LTI Activity 1",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          delivery_script: "lti_external_tool_delivery.js",
          authoring_script: "lti_external_tool_authoring.js",
          globally_available: false,
          globally_visible: true
        })

      lti_activity2 =
        insert(:activity_registration, %{
          slug: "lti_activity_2",
          title: "LTI Activity 2",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          delivery_script: "lti_external_tool_delivery.js",
          authoring_script: "lti_external_tool_authoring.js",
          globally_available: false,
          globally_visible: true
        })

      _non_lti_activity =
        insert(:activity_registration, %{
          slug: "non_lti_activity",
          title: "Non-LTI Activity",
          delivery_element: "non-lti-delivery",
          authoring_element: "non-lti-authoring",
          delivery_script: "non_lti_delivery.js",
          authoring_script: "non_lti_authoring.js",
          globally_available: false,
          globally_visible: true
        })

      deployment1 =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity1,
          deployment_id: Ecto.UUID.generate(),
          status: :enabled
        })

      deployment2 =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity2,
          deployment_id: Ecto.UUID.generate(),
          status: :enabled
        })

      [
        lti_activity1: lti_activity1,
        lti_activity2: lti_activity2,
        deployment1: deployment1,
        deployment2: deployment2
      ]
    end

    test "returns all LTI activity registrations when no ids are provided" do
      result = Oli.Activities.list_lti_activity_registrations()
      slugs = Enum.map(result, & &1.slug)
      assert "lti_activity_1" in slugs
      assert "lti_activity_2" in slugs
      assert length(result) == 2
    end

    test "returns only the LTI activity registrations matching the given ids", %{
      lti_activity1: lti1
    } do
      result = Oli.Activities.list_lti_activity_registrations([lti1.id])
      assert Enum.map(result, & &1.slug) == ["lti_activity_1"]
    end

    test "returns empty list if no LTI activity registrations match the given ids" do
      result = Oli.Activities.list_lti_activity_registrations([-1])
      assert result == []
    end
  end
end
