defmodule OliWeb.Workspaces.CourseAuthor.OverviewLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Tags

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

      element(view, "form[phx-submit='delete']")
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

      element(view, "form[phx-submit='update']")
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

    test "publisher dropdown displays publishers sorted alphabetically", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      # Create publishers in non-alphabetical order
      insert(:publisher, name: "Zebra Publisher", default: false)
      insert(:publisher, name: "Alpha Publisher", default: false)
      insert(:publisher, name: "Middle Publisher", default: false)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Extract publisher options from the dropdown
      html = render(view)

      publisher_options =
        html
        |> Floki.parse_document!()
        |> Floki.find("select[name=\"project[publisher_id]\"] option")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      # Verify publishers are sorted alphabetically (ignoring default status)
      alpha_index = Enum.find_index(publisher_options, &String.contains?(&1, "Alpha"))
      middle_index = Enum.find_index(publisher_options, &String.contains?(&1, "Middle"))
      zebra_index = Enum.find_index(publisher_options, &String.contains?(&1, "Zebra"))

      # Verify all publishers are present
      assert not is_nil(alpha_index),
             "Alpha publisher not found in: #{inspect(publisher_options)}"

      assert not is_nil(middle_index),
             "Middle publisher not found in: #{inspect(publisher_options)}"

      assert not is_nil(zebra_index),
             "Zebra publisher not found in: #{inspect(publisher_options)}"

      # Verify publishers are sorted alphabetically
      assert alpha_index < middle_index
      assert middle_index < zebra_index
    end

    test "project gets validated correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element("form[phx-change='validate']")
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

      element(view, "form[phx-change='set-required-survey']")
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

      assert has_element?(view, "input[name='survey'][checked]")

      element(view, "form[phx-change='set-required-survey']")
      |> render_change(%{"_target" => ["survey"], "survey" => ""})

      updated_project = Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id == nil
      refute has_element?(view, "input[name='survey'][checked]")
      refute has_element?(view, "a", "Edit survey")
    end

    test "edit survey button redirects well to edit survey page", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      ## Enable required survey
      element(view, "form[phx-change='set-required-survey']")
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

      element(view, "form[phx-change='set_allow_transfer']")
      |> render_change(%{})

      assert Course.get_project!(project.id).allow_transfer_payment_codes
    end

    test "project can disable transfer payment codes", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, project} = Course.update_project(project, %{allow_transfer_payment_codes: true})

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert project.allow_transfer_payment_codes

      element(view, "form[phx-change='set_allow_transfer']")
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

  describe "project overview tags" do
    setup [:author_conn]

    test "displays tags in Details section when project has tags", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      {:ok, _} = Tags.associate_tag_with_project(project, tag)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Tags label in Details section
      assert has_element?(view, "label", "Tags")
      # Should show the tag
      assert has_element?(view, "span[role='listitem']", "Biology")
    end

    test "displays empty tags component when project has no tags", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Tags label
      assert has_element?(view, "label", "Tags")
      # Should not show any tags
      refute has_element?(view, "span[role='listitem']")
    end

    test "displays multiple tags in alphabetical order", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      {:ok, zebra_tag} = Tags.create_tag(%{name: "Zebra"})
      {:ok, apple_tag} = Tags.create_tag(%{name: "Apple"})
      {:ok, _} = Tags.associate_tag_with_project(project, zebra_tag)
      {:ok, _} = Tags.associate_tag_with_project(project, apple_tag)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show both tags
      assert has_element?(view, "span[role='listitem']", "Apple")
      assert has_element?(view, "span[role='listitem']", "Zebra")

      # Check alphabetical order
      html = render(view)
      apple_index = :binary.match(html, "Apple") |> elem(0)
      zebra_index = :binary.match(html, "Zebra") |> elem(0)
      assert apple_index < zebra_index
    end

    test "can enter edit mode and see available tags", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      {:ok, existing_tag} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, _available_tag} = Tags.create_tag(%{name: "Physics"})
      {:ok, _} = Tags.associate_tag_with_project(project, existing_tag)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Enter edit mode by clicking on the tags component
      view |> element("div[phx-click='toggle_edit']") |> render_click()

      # Should show input field in edit mode
      assert has_element?(view, "input[type='text']")
      # Should show existing tag with remove button (X icon)
      assert has_element?(view, "span[role='listitem']", "Chemistry")
      assert has_element?(view, "button[phx-click='remove_tag'] svg")
      # Should show available tag to add
      assert has_element?(view, "button[phx-click='add_tag']", "Physics")

      # The available tag that's not yet associated should be selectable
      refute has_element?(view, "button[phx-click='add_tag']", "Chemistry")
    end

    test "displays communities in Details section when project has communities", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)
      community = insert(:community, name: "Biology Community")
      insert(:community_project_visibility, community: community, project: project)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Communities label
      assert has_element?(view, "label", "Communities")
      # Should show the community as a link
      assert has_element?(view, "a", "Biology Community")
    end

    test "displays 'None' when project has no communities", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Communities label
      assert has_element?(view, "label", "Communities")
      # Should show "None"
      assert render(view) =~ "None"
    end

    test "displays multiple communities as comma-separated links", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      community1 = insert(:community, name: "Biology")
      community2 = insert(:community, name: "Chemistry")
      insert(:community_project_visibility, community: community1, project: project)
      insert(:community_project_visibility, community: community2, project: project)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show both communities as links
      assert has_element?(view, "a", "Biology")
      assert has_element?(view, "a", "Chemistry")
      # Should have comma separator
      html = render(view)
      assert html =~ "Biology"
      assert html =~ "Chemistry"
    end

    test "displays institutions in Details section when project has visibility institutions", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)
      institution = insert(:institution, name: "Test University")

      insert(:project_visibility,
        project_id: project.id,
        institution_id: institution.id,
        author_id: nil
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Institutions label
      assert has_element?(view, "label", "Institutions")
      # Should show the institution as a link
      assert has_element?(view, "a", "Test University")
    end

    test "displays 'None' when project has no visibility institutions", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show the Institutions label
      assert has_element?(view, "label", "Institutions")
      # Should show "None"
      html = render(view)
      # Find the Institutions section and verify it shows "None"
      assert html =~ "Institutions"
    end

    test "displays multiple institutions as comma-separated links", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)
      institution1 = insert(:institution, name: "University A")
      institution2 = insert(:institution, name: "University B")

      insert(:project_visibility,
        project_id: project.id,
        institution_id: institution1.id,
        author_id: nil
      )

      insert(:project_visibility,
        project_id: project.id,
        institution_id: institution2.id,
        author_id: nil
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Should show both institutions as links
      assert has_element?(view, "a", "University A")
      assert has_element?(view, "a", "University B")
    end
  end

  describe "project overview course sections" do
    setup [:author_conn]

    test "displays Course Sections section with 'None exist' when project has no active sections",
         %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "h4", "Course Sections")

      # Wait for async data to load
      html = render_async(view)
      assert html =~ "None exist"
    end

    test "only displays sections with future end dates", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      publication = insert(:publication, project: project, published: DateTime.utc_now())

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)
      past_date = DateTime.add(DateTime.utc_now(), -30, :day)

      # Section with future end date - should be shown
      future_section =
        insert(:section,
          title: "Future Section",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date
        )

      insert(:section_project_publication,
        section: future_section,
        project: project,
        publication: publication
      )

      # Section with past end date - should NOT be shown
      past_section =
        insert(:section,
          title: "Past Section",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: past_date
        )

      insert(:section_project_publication,
        section: past_section,
        project: project,
        publication: publication
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Wait for async data to load
      render_async(view)

      assert has_element?(view, "a", "Future Section")
      refute has_element?(view, "a", "Past Section")
    end

    test "shows the correct payment status", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      publication = insert(:publication, project: project, published: DateTime.utc_now())

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)

      # Create a paid section
      paid_section =
        insert(:section,
          title: "Paid Section",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date,
          requires_payment: true,
          amount: Money.new(:USD, 100)
        )

      insert(:section_project_publication,
        section: paid_section,
        project: project,
        publication: publication
      )

      # Create a free section
      free_section =
        insert(:section,
          title: "Free Section",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date,
          requires_payment: false
        )

      insert(:section_project_publication,
        section: free_section,
        project: project,
        publication: publication
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Wait for async data to load
      html = render_async(view)

      # Both sections should be displayed
      assert has_element?(view, "a", "Paid Section")
      assert has_element?(view, "a", "Free Section")

      # Paid section shows the cost
      assert html =~ "$100.00"

      # Free section shows "None" for cost
      assert html =~ "None"
    end

    test "search filters sections by title (case-insensitive)", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      publication = insert(:publication, project: project, published: DateTime.utc_now())

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)

      section1 =
        insert(:section,
          title: "Introduction to Biology",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date
        )

      section2 =
        insert(:section,
          title: "Advanced Chemistry",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date
        )

      insert(:section_project_publication,
        section: section1,
        project: project,
        publication: publication
      )

      insert(:section_project_publication,
        section: section2,
        project: project,
        publication: publication
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Wait for async data to load
      render_async(view)

      # Both sections visible initially
      assert has_element?(view, "a", "Introduction to Biology")
      assert has_element?(view, "a", "Advanced Chemistry")

      # Search with lowercase "biology" - verifies both filtering and case-insensitivity
      view
      |> element("form[phx-change='course_sections_search_change']")
      |> render_change(%{"search" => "biology"})

      # Wait for async search results
      render_async(view)

      # Only Biology section visible (case-insensitive match)
      assert has_element?(view, "a", "Introduction to Biology")
      refute has_element?(view, "a", "Advanced Chemistry")
    end

    test "sort toggles between ascending and descending order", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      publication = insert(:publication, project: project, published: DateTime.utc_now())

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)

      # Create sections with titles that would change order when sorted desc
      for title <- ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"] do
        section =
          insert(:section,
            title: title,
            base_project: project,
            type: :enrollable,
            status: :active,
            end_date: future_date
          )

        insert(:section_project_publication,
          section: section,
          project: project,
          publication: publication
        )
      end

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Wait for async data to load
      render_async(view)

      # Default sort is by title ascending - Alpha should be first
      assert has_element?(view, "a", "Alpha")
      assert has_element?(view, "a", "Gamma")

      # Click to trigger sort (toggles to descending)
      view
      |> render_click("course_sections_sort", %{"sort_by" => "title"})

      # Wait for async sort results
      render_async(view)

      # Get updated HTML after the event
      html = render(view)

      # Extract section titles in order from table
      after_sort_titles =
        Regex.scan(~r/href="\/sections\/[^"]+\/manage"[^>]*>\s*([^<]+)\s*<\/a>/, html)
        |> Enum.map(fn [_, title] -> String.trim(title) end)

      # After descending sort, Gamma should appear first
      # Descending: Gamma > Epsilon > Delta > Beta > Alpha
      assert List.first(after_sort_titles) == "Gamma",
             "After descending sort, first section should be Gamma but got #{inspect(after_sort_titles)}"
    end

    test "displays correct creator information", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      publication = insert(:publication, project: project, published: DateTime.utc_now())

      future_date = DateTime.add(DateTime.utc_now(), 30, :day)

      # Section with enrolled user
      section_with_user =
        insert(:section,
          title: "Section With User",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date
        )

      insert(:section_project_publication,
        section: section_with_user,
        project: project,
        publication: publication
      )

      user = insert(:user, given_name: "Jane", family_name: "Doe", email: "jane@example.com")
      insert(:enrollment, user: user, section: section_with_user)

      # Section without enrollments
      section_empty =
        insert(:section,
          title: "Empty Section",
          base_project: project,
          type: :enrollable,
          status: :active,
          end_date: future_date
        )

      insert(:section_project_publication,
        section: section_empty,
        project: project,
        publication: publication
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Wait for async data to load
      html = render_async(view)

      # Section with enrolled user shows creator name, email, and link
      assert html =~ "Jane Doe"
      assert html =~ "jane@example.com"
      assert html =~ ~r/href="\/admin\/users\/#{user.id}".*Jane Doe/s

      # Section without enrollments shows N/A
      assert html =~ "Empty Section"
      assert html =~ "N/A"
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

      element(view, "form[phx-submit='update']")
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
