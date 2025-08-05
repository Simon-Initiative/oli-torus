defmodule OliWeb.Workspaces.CourseAuthor.OverviewLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Lti.PlatformExternalTools

  defp live_view_route(project_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/overview?#{params}"

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          flash: %{},
          to: "/authors/log_in"
        }}} = live(conn, live_view_route("project-slug"))
    end
  end

  describe "project overview as author" do
    setup [:author_conn]

    test "loads the project correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Publishing Visibility")
      assert has_element?(view, "h4", "Notes")
      assert has_element?(view, "h4", "Course Discussions")
      assert has_element?(view, "h4", "Transfer Payment Codes")
      assert has_element?(view, "h4", "Actions")

      refute has_element?(view, "button", "Bulk Resource Attribute Edit")
      refute has_element?(view, "label", "Calculate embeddings on publish")
    end

    test "project gets deleted correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      element(view, "form[phx-submit=\"delete\"]")
      |> render_submit()
      |> follow_redirect(conn, "/workspaces/course_author")

      assert Course.get_project_by_slug(project.slug).status == :deleted
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "button#button-new-project")
      refute has_element?(view, "a", project.title)
    end

    test "project gets updated correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      welcome_title = %{
        "type" => "p",
        "children" => [
          %{
            "id" => "2748906063",
            "type" => "p",
            "children" => [%{"text" => "Welcome Title"}]
          }
        ]
      }

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      element(view, "form[phx-submit=\"update\"]")
      |> render_submit(%{
        "project" => %{
          "title" => "updated title",
          "description" => "updated description",
          "welcome_title" => Poison.encode!(welcome_title),
          "encouraging_subtitle" => "updated encouraging subtitle"
        }
      })

      assert has_element?(view, "div.alert-info", "Project updated successfully.")
      assert has_element?(view, "input[name=\"project[title]\"][value=\"updated title\"]")
      assert has_element?(view, "textarea[name=\"project[description]\"]", "updated description")
      assert has_element?(view, "#header", "updated title")

      assert has_element?(
               view,
               "textarea[name=\"project[encouraging_subtitle]\"]",
               "updated encouraging subtitle"
             )

      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{div[data-live-react-class="Components.RichTextEditor"]})
      |> Floki.attribute("data-live-react-props")
      |> hd() =~ "Welcome Title"
    end

    test "project gets validated correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element("form[phx-change=\"validate\"]")
             |> render_change(%{
               "project" => %{
                 "title" => nil
               }
             }) =~ "can&#39;t be blank"
    end

    test "project can enable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      refute has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{
        survey: "on"
      })

      updated_project = Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id != nil
      assert has_element?(view, "input[name=\"survey\"][checked]")
      assert has_element?(view, "a", "Edit survey")
    end

    test "project can disable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      Course.create_project_survey(project, author.id)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{})

      updated_project = Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id == nil
      refute has_element?(view, "input[name=\"survey\"][checked]")
      refute has_element?(view, "a", "Edit survey")
    end

    test "edit survey button redirects well to edit survey page", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      ## Enable required survey
      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{
        survey: "on"
      })

      ## Click on edit survey button
      element(view, "a", "Edit survey") |> render_click()

      ## Assert redirection to edit survey page
      assert_redirected(
        view,
        ~p{/workspaces/course_author/#{project.slug}/curriculum/course_survey/edit}
      )
    end

    test "project can enable transfer payment codes", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      refute project.allow_transfer_payment_codes

      element(view, "form[phx-change=\"set_allow_transfer\"]")
      |> render_change(%{})

      assert Course.get_project!(project.id).allow_transfer_payment_codes
    end

    test "project can disable transfer payment codes", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, project} = Course.update_project(project, %{allow_transfer_payment_codes: true})

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert project.allow_transfer_payment_codes

      element(view, "form[phx-change=\"set_allow_transfer\"]")
      |> render_change(%{})

      refute Course.get_project!(project.id).allow_transfer_payment_codes
    end

    test "advanced activities are shown correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      # Add some activities to the project
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

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Advanced Activities")

      # Should show both activities
      assert has_element?(view, "div", activity1.title)
      assert has_element?(view, "div", activity2.title)
    end

    test "external tools activities are shown correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      external_tool_1_params = %{
        "name" => "External Too Test 1",
        "description" => "External Tool Description",
        "client_id" => "new_tool_client_id_1",
        "target_link_uri" => "https://example.com/launch",
        "login_url" => "https://example.com/login",
        "keyset_url" => "https://example.com/jwks",
        "redirect_uris" => "https://example.com/redirect",
        "custom_params" => "param1=value1&param2=value2"
      }

      external_tool_2_params = %{
        "name" => "External Tool Test 2",
        "description" => "External Tool Description",
        "client_id" => "new_tool_client_id_2",
        "target_link_uri" => "https://example.com/launch",
        "login_url" => "https://example.com/login",
        "keyset_url" => "https://example.com/jwks",
        "redirect_uris" => "https://example.com/redirect",
        "custom_params" => "param1=value1&param2=value2"
      }

      {:ok, {_platform_instance_1, activity_registration_1, deployment_1}} =
        PlatformExternalTools.register_lti_external_tool_activity(external_tool_1_params)

      {:ok, {_platform_instance_2, activity_registration_2, deployment_2}} =
        PlatformExternalTools.register_lti_external_tool_activity(external_tool_2_params)

      # Add activities to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity_registration_1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: activity_registration_2.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Advanced Activities")

      assert has_element?(view, "div", activity_registration_1.title)
      assert has_element?(view, "span", deployment_1.deployment_id)

      assert has_element?(view, "div", activity_registration_2.title)
      assert has_element?(view, "span", deployment_2.deployment_id)
    end

    test "disabled or soft deleted external tools activities are not shown", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      external_tool_1_params = %{
        "name" => "External Too Test 1",
        "description" => "External Tool Description",
        "client_id" => "new_tool_client_id_1",
        "target_link_uri" => "https://example.com/launch",
        "login_url" => "https://example.com/login",
        "keyset_url" => "https://example.com/jwks",
        "redirect_uris" => "https://example.com/redirect",
        "custom_params" => "param1=value1&param2=value2"
      }

      {:ok, {_platform_instance_1, activity_registration_1, deployment_1}} =
        PlatformExternalTools.register_lti_external_tool_activity(external_tool_1_params)

      # Disable the tool
      PlatformExternalTools.update_lti_external_tool_activity_deployment(
        deployment_1,
        %{"status" => :disabled}
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Advanced Activities")

      refute has_element?(view, "div", activity_registration_1.title)

      # Soft delete the tool
      PlatformExternalTools.update_lti_external_tool_activity_deployment(
        deployment_1,
        %{"status" => :deleted}
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Advanced Activities")

      refute has_element?(view, "div", activity_registration_1.title)
    end

    test "shows add activities and tools button", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "button", "+ Add Activities and Tools")
    end

    test "opens modal when add activities button is clicked", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # the modal is present but hidden by default
      assert has_element?(view, "#add-activities-tools")
      assert has_element?(view, "#add-activities-tools-modal")

      # Click the add activities button
      view
      |> element("button", "+ Add Activities and Tools")
      |> render_click()

      # Should trigger the show_modal event and load modal content
      # The modal should be visible after the click and contain the expected content
      assert has_element?(view, "h1", "Add Advanced Activities & External Tools")
      assert has_element?(view, "button", "Advanced Activities")
      assert has_element?(view, "button", "External Tools")
    end

    test "handles flash messages from modal", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Send info flash message (simulating from modal)
      send(view.pid, {:flash_message, {:info, "Test message"}})
      assert has_element?(view, ".alert.alert-info", "Test message")

      # Send error flash message (simulating from modal)
      send(view.pid, {:flash_message, {:error, "Test error message"}})
      assert has_element?(view, ".alert.alert-danger", "Test error message")
    end

    test "refreshes activities when refresh message is received", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      # Add initial advanced activity
      activity1 =
        insert(:activity_registration, %{
          title: "Initial Activity",
          globally_visible: true,
          globally_available: false
        })

      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      # create ativity 2, but do not yet add it to the project
      activity2 =
        insert(:activity_registration, %{
          title: "New Activity",
          globally_visible: true,
          globally_available: false
        })

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show initial advanced activity, but not the one not yet added to the project
      assert has_element?(view, "div", activity1.title)
      refute has_element?(view, "div", activity2.title)

      # Simulate an advanced activity was added by the modal
      # so the modal informs back to the live view that the activities were updated

      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :enabled
      })

      # Send refresh message (simulating from modal)
      send(view.pid, {:refresh_tools_and_activities})

      # Should still show the advanced activity after refresh
      # and show the just added advanced activity
      assert has_element?(view, "div", activity1.title)
      assert has_element?(view, "div", activity2.title)
    end

    defp create_project_with_author(author) do
      %{project: project} = base_project_with_curriculum(nil)
      insert(:author_project, project_id: project.id, author_id: author.id)
      project
    end
  end

  describe "project overview as admin" do
    setup [:admin_conn]

    test "loads the project correctly", %{conn: conn, admin: admin} do
      project = create_project_with_author(admin)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))
      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Publishing Visibility")
      assert has_element?(view, "h4", "Notes")
      assert has_element?(view, "h4", "Course Discussions")
      assert has_element?(view, "h4", "Actions")

      assert has_element?(view, "a", "Bulk Resource Attribute Edit")
      assert has_element?(view, "label", "Calculate embeddings on publish")
    end

    test "can update calculate_embeddings_on_publish attribute (false by default)", %{
      conn: conn,
      admin: admin
    } do
      project = create_project_with_author(admin)

      Oli.Publishing.publish_project(
        project,
        "Datashop test",
        admin.id
      )

      refute project.attributes.calculate_embeddings_on_publish

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      element(view, "form[phx-submit=\"update\"]")
      |> render_submit(%{
        "project" => %{
          "attributes" => %{
            "calculate_embeddings_on_publish" => "true"
          }
        }
      })

      assert Course.get_project!(project.id).attributes.calculate_embeddings_on_publish
    end
  end
end
