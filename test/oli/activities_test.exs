defmodule Oli.ActivitiesTest do
  use Oli.DataCase
  import ExUnit.Assertions
  import Oli.Factory
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolProjectGrant

  setup [:author_project_fixture]

  describe "add activity to project" do
    test "adding a custom registered activity to a project", %{project: project} do
      custom_activity = Activities.get_registration_by_slug("oli_image_coding")

      # Add and enable the activity using bulk operation
      Activities.bulk_update_project_activities(project.id, [custom_activity.id], [], false)
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

    test "disabling a custom registered activity from a project", %{project: project} do
      custom_activity = Activities.get_registration_by_slug("oli_image_coding")

      # First add the activity to the project
      Activities.bulk_update_project_activities(project.id, [custom_activity.id], [], false)
      # Then disable it
      Activities.disable_activity_in_project(project.id, custom_activity.id)

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

      # Add and enable the activity using bulk operation
      Activities.bulk_update_project_activities(project.id, [custom_activity.id], [], false)
      editor_menu_items = Activities.create_registered_activity_map(project.slug)

      image_coding = Map.get(editor_menu_items, "oli_image_coding")
      assert !image_coding.globallyAvailable and image_coding.enabledForProject
    end
  end

  describe "bulk_update_project_activities/4" do
    test "bulk add and remove activities efficiently", %{project: project} do
      # Create some test activities (must be advanced activities)
      activity1 =
        insert(:activity_registration, %{
          slug: "test_activity_1",
          title: "Test Activity 1",
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          slug: "test_activity_2",
          title: "Test Activity 2",
          globally_available: false
        })

      activity3 =
        insert(:activity_registration, %{
          slug: "test_activity_3",
          title: "Test Activity 3",
          globally_available: false
        })

      # Initially add activity1 and activity2 to the project
      Activities.bulk_update_project_activities(
        project.id,
        [activity1.id, activity2.id],
        [],
        false
      )

      # Verify they are in the project
      selected_activities = Activities.selected_activities_for_project(project.id)
      selected_ids = Enum.map(selected_activities, & &1.id)
      assert activity1.id in selected_ids
      assert activity2.id in selected_ids
      assert activity3.id not in selected_ids

      # Use bulk operation to: add activity3, remove activity1, keep activity2
      result =
        Activities.bulk_update_project_activities(
          project.id,
          # add
          [activity3.id],
          # remove
          [activity1.id],
          false
        )

      assert result == :ok

      # Verify the changes
      selected_activities_after = Activities.selected_activities_for_project(project.id)
      selected_ids_after = Enum.map(selected_activities_after, & &1.id)
      assert activity1.id not in selected_ids_after
      assert activity2.id in selected_ids_after
      assert activity3.id in selected_ids_after
    end

    test "bulk operation with empty lists", %{project: project} do
      # Should handle empty lists gracefully
      result = Activities.bulk_update_project_activities(project.id, [], [], false)
      assert result == :ok
    end
  end

  describe "preview activity registration infrastructure" do
    test "register_activity/2 persists normalized preview metadata" do
      manifest = %Oli.Activities.Manifest{
        id: "test_preview_activity",
        friendlyName: "Test Preview Activity",
        petiteLabel: "TPA",
        description: "Test preview activity",
        icon: "icon",
        delivery: %Oli.Activities.ModeSpecification{
          element: "test-preview-delivery",
          entry: "./delivery-entry.ts"
        },
        authoring: %Oli.Activities.ModeSpecification{
          element: "test-preview-authoring",
          entry: "./authoring-entry.ts"
        },
        preview: %Oli.Activities.ModeSpecification{
          element: "test-preview-preview",
          entry: "./preview-entry.ts"
        },
        allowClientEvaluation: false,
        global: false,
        variables: [],
        generatesReport: false,
        activityRegistration: true
      }

      assert {:ok, registration} = Activities.register_activity(manifest)
      assert registration.preview_element == "test-preview-preview"
      assert registration.preview_script == "test_preview_activity_preview.js"
    end

    test "activities_for_section/0 includes preview metadata" do
      activity =
        insert(:activity_registration, %{
          slug: "preview_section_activity",
          title: "Preview Section Activity",
          preview_element: "preview-section-activity-preview",
          preview_script: "preview_section_activity_preview.js"
        })

      result = Activities.activities_for_section()

      assert Enum.any?(result, fn entry ->
               entry.id == activity.id and
                 entry.preview_element == "preview-section-activity-preview" and
                 entry.preview_script == "preview_section_activity_preview.js"
             end)
    end
  end

  describe "selectable_activities_for_project/2" do
    test "returns all advanced activities for admin users (regardless of visibility)", %{
      project: project
    } do
      # Create advanced activities with different visibility
      activity1 =
        insert(:activity_registration, %{
          title: "Test Activity 1",
          globally_visible: true,
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          title: "Test Activity 2",
          globally_visible: false,
          globally_available: false
        })

      activity3 =
        insert(:activity_registration, %{
          title: "Test Activity 3",
          globally_visible: true,
          globally_available: false
        })

      # Create a regular activity (globally_available: true) - should be excluded
      regular_activity =
        insert(:activity_registration, %{
          title: "Regular Activity",
          globally_visible: true,
          globally_available: true
        })

      result = Activities.selectable_activities_for_project(project.id, true)

      # Should return all advanced activities for admin, but exclude regular activities
      activity_ids = Enum.map(result, & &1.id)
      assert activity1.id in activity_ids
      assert activity2.id in activity_ids
      assert activity3.id in activity_ids
      assert regular_activity.id not in activity_ids
    end

    test "returns only globally visible advanced activities for non-admin users", %{
      project: project
    } do
      # Create advanced activities with different visibility
      activity1 =
        insert(:activity_registration, %{
          title: "Test Activity 1",
          globally_visible: true,
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          title: "Test Activity 2",
          globally_visible: false,
          globally_available: false
        })

      activity3 =
        insert(:activity_registration, %{
          title: "Test Activity 3",
          globally_visible: true,
          globally_available: false
        })

      # Create a regular activity (globally_available: true) - should be excluded
      regular_activity =
        insert(:activity_registration, %{
          title: "Regular Activity",
          globally_visible: true,
          globally_available: true
        })

      result = Activities.selectable_activities_for_project(project.id, false)

      # Should only return globally visible advanced activities
      activity_ids = Enum.map(result, & &1.id)
      assert activity1.id in activity_ids
      assert activity2.id not in activity_ids
      assert activity3.id in activity_ids
      assert regular_activity.id not in activity_ids
    end

    test "excludes regular activities (globally_available: true)", %{project: project} do
      # Create regular activities that should be excluded
      regular_activity1 =
        insert(:activity_registration, %{
          title: "Regular Activity 1",
          globally_available: true,
          globally_visible: true
        })

      regular_activity2 =
        insert(:activity_registration, %{
          title: "Regular Activity 2",
          globally_available: true,
          globally_visible: false
        })

      # Create advanced activities that should be included
      advanced_activity1 =
        insert(:activity_registration, %{
          title: "Advanced Activity 1",
          globally_available: false,
          globally_visible: true
        })

      advanced_activity2 =
        insert(:activity_registration, %{
          title: "Advanced Activity 2",
          globally_available: false,
          globally_visible: false
        })

      result = Activities.selectable_activities_for_project(project.id, true)

      # Should exclude all regular activities regardless of visibility
      activity_ids = Enum.map(result, & &1.id)
      assert regular_activity1.id not in activity_ids
      assert regular_activity2.id not in activity_ids

      # Should include advanced activities based on admin status
      assert advanced_activity1.id in activity_ids
      assert advanced_activity2.id in activity_ids
    end

    test "filters LTI tools by deployment status", %{project: project} do
      # Create LTI activity with deployment (must be advanced activity)
      lti_activity =
        insert(:activity_registration, %{
          title: "LTI Activity",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          globally_available: false
        })

      # Create enabled deployment
      deployment =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity,
          status: :enabled
        })

      result = Activities.selectable_activities_for_project(project.id, true)

      # Should include the LTI activity with enabled deployment
      lti_result = Enum.find(result, &(&1.id == lti_activity.id))
      assert lti_result.deployment_id == deployment.deployment_id
    end

    test "excludes LTI tools with disabled deployment", %{project: project} do
      # Create LTI activity with disabled deployment (must be advanced activity)
      lti_activity =
        insert(:activity_registration, %{
          title: "LTI Activity",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          globally_available: false
        })

      _deployment =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity,
          status: :disabled
        })

      result = Activities.selectable_activities_for_project(project.id, true)

      # Should not include the LTI activity with disabled deployment
      refute Enum.find(result, &(&1.id == lti_activity.id))
    end

    test "includes project status for activities already in project", %{project: project} do
      activity =
        insert(:activity_registration, %{
          title: "Test Activity",
          globally_visible: true,
          globally_available: false
        })

      # Add activity to project with enabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :enabled
      })

      result = Activities.selectable_activities_for_project(project.id, true)
      activity_result = Enum.find(result, &(&1.id == activity.id))

      assert activity_result.project_status == :enabled
    end

    test "orders results by deployment_id desc and title asc", %{project: project} do
      # Create advanced activities with different titles
      _activity_a =
        insert(:activity_registration, %{
          title: "A Activity",
          globally_visible: true,
          globally_available: false
        })

      _activity_b =
        insert(:activity_registration, %{
          title: "B Activity",
          globally_visible: true,
          globally_available: false
        })

      _activity_c =
        insert(:activity_registration, %{
          title: "C Activity",
          globally_visible: true,
          globally_available: false
        })

      # Create LTI activities with different deployment IDs (must be advanced activities)
      lti_activity_1 =
        insert(:activity_registration, %{
          title: "LTI Activity 1",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          globally_available: false
        })

      lti_activity_2 =
        insert(:activity_registration, %{
          title: "LTI Activity 2",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          globally_available: false
        })

      _deployment_1 =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity_1,
          deployment_id: Ecto.UUID.generate(),
          status: :enabled
        })

      _deployment_2 =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity_2,
          deployment_id: Ecto.UUID.generate(),
          status: :enabled
        })

      result = Activities.selectable_activities_for_project(project.id, true)

      # Get titles in order
      titles = Enum.map(result, & &1.title)

      # activities should be ordered alphabetically
      assert Enum.find_index(titles, &(&1 == "A Activity")) <
               Enum.find_index(titles, &(&1 == "B Activity"))

      assert Enum.find_index(titles, &(&1 == "B Activity")) <
               Enum.find_index(titles, &(&1 == "C Activity"))
    end
  end

  describe "selected_activities_for_project/2" do
    test "returns only advanced activities that are in the project", %{project: project} do
      # Create advanced activities
      activity1 =
        insert(:activity_registration, %{
          title: "Test Activity 1",
          globally_visible: true,
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          title: "Test Activity 2",
          globally_visible: true,
          globally_available: false
        })

      activity3 =
        insert(:activity_registration, %{
          title: "Test Activity 3",
          globally_visible: true,
          globally_available: false
        })

      # Create a regular activity that should be excluded even if added to project
      regular_activity =
        insert(:activity_registration, %{
          title: "Regular Activity",
          globally_visible: true,
          globally_available: true
        })

      # Add only activity1, activity2, and regular_activity to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :disabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: regular_activity.id,
        project_id: project.id,
        status: :enabled
      })

      result = Activities.selected_activities_for_project(project.id, true)

      # Should only return advanced activities that were added to the project, exclude regular activities
      activity_ids = Enum.map(result, & &1.id)
      assert activity1.id in activity_ids
      assert activity2.id in activity_ids
      assert activity3.id not in activity_ids
      assert regular_activity.id not in activity_ids
    end

    test "includes project status for each activity", %{project: project} do
      activity =
        insert(:activity_registration, %{
          title: "Test Activity",
          globally_visible: true,
          globally_available: false
        })

      # Add activity to project with disabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :disabled
      })

      result = Activities.selected_activities_for_project(project.id, true)
      activity_result = Enum.find(result, &(&1.id == activity.id))

      assert activity_result.project_status == :disabled
    end

    test "filters by admin status", %{project: project} do
      # Create advanced activities with different visibility
      activity1 =
        insert(:activity_registration, %{
          title: "Test Activity 1",
          globally_visible: true,
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          title: "Test Activity 2",
          globally_visible: false,
          globally_available: false
        })

      # Add both activities to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :enabled
      })

      # Admin should see both
      admin_result = Activities.selected_activities_for_project(project.id, true)
      admin_ids = Enum.map(admin_result, & &1.id)
      assert activity1.id in admin_ids
      assert activity2.id in admin_ids

      # Non-admin should only see globally visible
      non_admin_result = Activities.selected_activities_for_project(project.id, false)
      non_admin_ids = Enum.map(non_admin_result, & &1.id)
      assert activity1.id in non_admin_ids
      assert activity2.id not in non_admin_ids
    end
  end

  describe "enable_activity_in_project/2" do
    test "enables an existing activity in project", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity with disabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :disabled
      })

      result = Activities.enable_activity_in_project(project.id, activity.id)

      assert result == :ok

      # Verify status was updated
      selected_activities = Activities.selected_activities_for_project(project.id)
      activity_result = Enum.find(selected_activities, &(&1.id == activity.id))
      assert activity_result.project_status == :enabled
    end

    test "returns error for non-existent activity in project", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      result = Activities.enable_activity_in_project(project.id, activity.id)

      assert result == {:error, "No ActivityRegistrationProject found"}
    end
  end

  describe "disable_activity_in_project/2" do
    test "disables an existing activity in project", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity with enabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :enabled
      })

      result = Activities.disable_activity_in_project(project.id, activity.id)

      assert result == :ok

      # Verify status was updated
      selected_activities = Activities.selected_activities_for_project(project.id)
      activity_result = Enum.find(selected_activities, &(&1.id == activity.id))
      assert activity_result.project_status == :disabled
    end

    test "returns error for non-existent activity in project", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      result = Activities.disable_activity_in_project(project.id, activity.id)

      assert result == {:error, "No ActivityRegistrationProject found"}
    end
  end

  describe "create_registered_activity_map/1" do
    test "returns map with correct structure", %{project: project} do
      result = Activities.create_registered_activity_map(project.slug)
      # Should return a map
      assert is_map(result)

      # Check structure of first entry
      {first_slug, first_entry} = Enum.at(result, 0)
      assert is_binary(first_slug)
      assert Map.has_key?(first_entry, :enabledForProject)
      assert Map.has_key?(first_entry, :slug)
      assert Map.has_key?(first_entry, :friendlyName)
    end

    test "correctly identifies enabled activities", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity to project
      Activities.bulk_update_project_activities(project.id, [activity.id], [], false)

      result = Activities.create_registered_activity_map(project.slug)
      activity_entry = Map.get(result, activity.slug)

      assert activity_entry.enabledForProject == true
    end

    test "correctly identifies disabled activities", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity to project
      Activities.bulk_update_project_activities(project.id, [activity.id], [], false)
      # Disable it
      Activities.disable_activity_in_project(project.id, activity.id)

      result = Activities.create_registered_activity_map(project.slug)
      activity_entry = Map.get(result, activity.slug)

      # The activity should still be in the map but not enabled for the project
      assert activity_entry.enabledForProject == false
    end

    test "returns error for non-existent project" do
      result = Activities.create_registered_activity_map("non-existent-project")
      assert {:error, "The project was not found."} = result
    end
  end

  describe "activities_for_project/2" do
    test "returns activities with correct structure", %{project: project} do
      result = Activities.activities_for_project(project)

      # Should return a list
      assert is_list(result)

      # Check structure of first activity
      if length(result) > 0 do
        first_activity = List.first(result)
        assert Map.has_key?(first_activity, :id)
        assert Map.has_key?(first_activity, :title)
        assert Map.has_key?(first_activity, :enabled)
        assert Map.has_key?(first_activity, :global)
        assert Map.has_key?(first_activity, :slug)
      end
    end

    test "correctly identifies enabled activities", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity to project
      Activities.bulk_update_project_activities(project.id, [activity.id], [], false)

      result = Activities.activities_for_project(project)
      activity_result = Enum.find(result, &(&1.id == activity.id))

      assert activity_result.enabled == true
    end

    test "correctly identifies disabled activities", %{project: project} do
      activity =
        insert(:activity_registration, %{title: "Test Activity", globally_available: false})

      # Add activity to project
      Activities.bulk_update_project_activities(project.id, [activity.id], [], false)
      # Disable it
      Activities.disable_activity_in_project(project.id, activity.id)

      result = Activities.activities_for_project(project)
      activity_result = Enum.find(result, &(&1.id == activity.id))

      # The activity should still be in the result but not enabled
      assert activity_result.enabled == false
    end

    test "respects admin vs non-admin visibility", %{project: project} do
      # Create activities with different visibility
      activity1 =
        insert(:activity_registration, %{title: "Test Activity 1", globally_visible: true})

      activity2 =
        insert(:activity_registration, %{title: "Test Activity 2", globally_visible: false})

      # Admin should see both
      admin_result = Activities.activities_for_project(project, true)
      admin_ids = Enum.map(admin_result, & &1.id)
      assert activity1.id in admin_ids
      assert activity2.id in admin_ids

      # Non-admin should only see globally visible
      non_admin_result = Activities.activities_for_project(project, false)
      non_admin_ids = Enum.map(non_admin_result, & &1.id)
      assert activity1.id in non_admin_ids
      assert activity2.id not in non_admin_ids
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

  describe "LTI external tool eligibility for a project" do
    test "a project can add a public tool, a private tool granted to it and an advanced activity",
         %{project: project} do
      public = lti_tool("Public Tool", %{availability: :public})
      granted = lti_tool("Granted Tool", %{availability: :private})
      grant(granted, project)
      advanced = insert(:activity_registration, %{title: "Advanced", globally_available: false})

      ids = selectable_ids(project, false)
      assert public.registration.id in ids
      assert granted.registration.id in ids
      assert advanced.id in ids

      assert :ok ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [public.registration.id, granted.registration.id, advanced.id],
                 [],
                 false
               )

      assert associated?(public.registration, project)
      assert associated?(granted.registration, project)
      assert associated?(advanced, project)
    end

    test "a private tool without a grant for the project is neither offered nor added",
         %{project: project} do
      ungranted = lti_tool("Ungranted Tool", %{availability: :private})
      grant(ungranted, insert(:project))
      granted = lti_tool("Granted Tool", %{availability: :private})
      grant(granted, project)
      public = lti_tool("Public Tool", %{availability: :public})

      for is_admin? <- [false, true] do
        ids = selectable_ids(project, is_admin?)
        assert public.registration.id in ids
        assert granted.registration.id in ids
        refute ungranted.registration.id in ids

        assert {:error, {:not_addable, ["Ungranted Tool"]}} ==
                 Activities.bulk_update_project_activities(
                   project.id,
                   [ungranted.registration.id],
                   [],
                   is_admin?
                 )
      end

      refute associated?(ungranted.registration, project)
    end

    test "a disabled tool is neither offered nor added, even when public or granted",
         %{project: project} do
      disabled_public = lti_tool("Disabled Public", %{availability: :public, status: :disabled})

      disabled_granted =
        lti_tool("Disabled Granted", %{availability: :private, status: :disabled})

      grant(disabled_granted, project)
      enabled = lti_tool("Enabled Public", %{availability: :public})

      ids = selectable_ids(project, false)
      assert enabled.registration.id in ids
      refute disabled_public.registration.id in ids
      refute disabled_granted.registration.id in ids

      assert {:error, {:not_addable, ["Disabled Granted", "Disabled Public"]}} ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [disabled_public.registration.id, disabled_granted.registration.id],
                 [],
                 false
               )

      assert :ok ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [enabled.registration.id],
                 [],
                 false
               )

      refute associated?(disabled_public.registration, project)
      refute associated?(disabled_granted.registration, project)
      assert associated?(enabled.registration, project)
    end

    test "an admin cannot add a private tool without a grant either", %{project: project} do
      ungranted = lti_tool("Ungranted Tool", %{availability: :private})

      admin_only =
        lti_tool("Admin Only Tool", %{availability: :public}, %{globally_visible: false})

      assert admin_only.registration.id in selectable_ids(project, true)
      refute admin_only.registration.id in selectable_ids(project, false)
      refute ungranted.registration.id in selectable_ids(project, true)

      assert {:error, {:not_addable, ["Ungranted Tool"]}} ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [ungranted.registration.id],
                 [],
                 true
               )

      assert {:error, {:not_addable, ["Admin Only Tool"]}} ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [admin_only.registration.id],
                 [],
                 false
               )

      refute associated?(admin_only.registration, project)

      assert :ok ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [admin_only.registration.id],
                 [],
                 true
               )

      assert associated?(admin_only.registration, project)
      refute associated?(ungranted.registration, project)
    end

    test "a private tool added before it lost its grant stays listed, can be removed and cannot be added again",
         %{project: project} do
      kept_enabled = lti_tool("Kept Enabled", %{availability: :private})
      kept_disabled = lti_tool("Kept Disabled", %{availability: :private})
      associate(kept_enabled, project, :enabled)
      associate(kept_disabled, project, :disabled)

      listed =
        project.id
        |> Activities.selectable_activities_for_project(false)
        |> Map.new(&{&1.id, &1.project_status})

      assert listed[kept_enabled.registration.id] == :enabled
      assert listed[kept_disabled.registration.id] == :disabled

      assert :ok ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [],
                 [kept_enabled.registration.id, kept_disabled.registration.id],
                 false
               )

      refute associated?(kept_enabled.registration, project)
      refute associated?(kept_disabled.registration, project)
      refute kept_enabled.registration.id in selectable_ids(project, false)

      assert {:error, {:not_addable, ["Kept Enabled"]}} ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [kept_enabled.registration.id],
                 [],
                 false
               )

      refute associated?(kept_enabled.registration, project)
    end

    test "a batch with one tool that cannot be added changes nothing", %{project: project} do
      ungranted = lti_tool("Ungranted Tool", %{availability: :private})
      public = lti_tool("Public Tool", %{availability: :public})
      existing = lti_tool("Existing Tool", %{availability: :public})
      associate(existing, project, :enabled)

      assert {:error, {:not_addable, ["Ungranted Tool"]}} ==
               Activities.bulk_update_project_activities(
                 project.id,
                 [ungranted.registration.id, public.registration.id],
                 [existing.registration.id],
                 false
               )

      refute associated?(ungranted.registration, project)
      refute associated?(public.registration, project)
      assert associated?(existing.registration, project)
    end
  end

  describe "can_create_activity?/3" do
    test "a hidden public LTI tool is creatable only by an admin", %{project: project} do
      tool =
        lti_tool("Admin Only Tool", %{availability: :public}, %{globally_visible: false})

      refute Activities.can_create_activity?(tool.registration, project.id, false)
      assert Activities.can_create_activity?(tool.registration, project.id, true)
    end

    test "a hidden non-global registration without an LTI deployment remains creatable", %{
      project: project
    } do
      registration =
        insert(:activity_registration, globally_available: false, globally_visible: false)

      assert Activities.can_create_activity?(registration, project.id, false)
      assert Activities.can_create_activity?(registration, project.id, true)
    end
  end

  defp lti_tool(title, deployment_attrs, registration_attrs \\ %{}) do
    registration =
      insert(
        :activity_registration,
        Map.merge(
          %{title: title, globally_visible: true, globally_available: false},
          registration_attrs
        )
      )

    deployment =
      insert(
        :lti_external_tool_activity_deployment,
        Map.put(deployment_attrs, :activity_registration, registration)
      )

    %{registration: registration, deployment: deployment}
  end

  defp grant(%{deployment: deployment}, project) do
    Repo.insert!(%LtiExternalToolProjectGrant{
      deployment_id: deployment.deployment_id,
      project_id: project.id
    })
  end

  defp associate(%{registration: registration}, project, status) do
    insert(:activity_registration_project, %{
      activity_registration_id: registration.id,
      project_id: project.id,
      status: status
    })
  end

  defp selectable_ids(project, is_admin?) do
    project.id
    |> Activities.selectable_activities_for_project(is_admin?)
    |> MapSet.new(& &1.id)
  end

  defp associated?(registration, project) do
    not is_nil(
      Repo.get_by(ActivityRegistrationProject,
        activity_registration_id: registration.id,
        project_id: project.id
      )
    )
  end
end
