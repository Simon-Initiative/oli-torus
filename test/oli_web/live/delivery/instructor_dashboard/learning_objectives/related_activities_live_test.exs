defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivitiesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  defp live_view_related_activities_route(section_slug, resource_id, params \\ %{}) do
    base_path =
      ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives/related_activities/#{resource_id}"

    if Enum.empty?(params) do
      base_path
    else
      query_string = URI.encode_query(params)
      "#{base_path}?#{query_string}"
    end
  end

  describe "authentication and authorization" do
    test "redirects unauthenticated users", %{conn: conn} do
      section = insert(:section, type: :enrollable)

      objective =
        insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_objective())

      redirect_path = "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_related_activities_route(section.slug, objective.resource_id))
    end

    test "allows enrolled instructors", %{conn: conn} do
      instructor = user_fixture(%{can_create_sections: true})

      %{section: section, objective_a: objective_a} =
        setup_activities_with_objectives(%{instructor: instructor})

      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(conn, live_view_related_activities_route(section.slug, objective_a.resource_id))

      assert has_element?(view, "h1", objective_a.title)
    end

    test "denies non-enrolled users", %{conn: conn} do
      user = user_fixture()
      section = insert(:section, type: :enrollable)

      objective =
        insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_objective())

      conn = log_in_user(conn, user)

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_related_activities_route(section.slug, objective.resource_id))
    end
  end

  describe "related activities functionality" do
    setup [:instructor_conn, :setup_activities_with_objectives]

    defp setup_activities_with_objectives(%{instructor: instructor}) do
      # Create author and project
      author = insert(:author)
      project = insert(:project, authors: [author])

      # Create objectives
      objective_a =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective A - Understanding Concepts"
        )

      objective_b =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective B - Problem Solving"
        )

      sub_objective_a1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Sub-objective A.1 - Basic Concepts"
        )

      objective_without_activities =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective Without Activities"
        )

      # Create activities with objectives attached
      activity_1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          title: "Activity 1 - Basic Math",
          content: %{
            "stem" => %{
              "content" => [
                %{
                  "type" => "p",
                  "children" => [%{"text" => "What is 2 + 2?"}]
                }
              ]
            }
          },
          objectives: %{"1" => [objective_a.resource_id]}
        )

      activity_2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          title: "Activity 2 - Advanced Math",
          content: %{
            "stem" => %{
              "content" => [
                %{
                  "type" => "p",
                  "children" => [%{"text" => "Solve for x: 2x + 5 = 15"}]
                }
              ]
            }
          },
          objectives: %{"1" => [objective_b.resource_id]}
        )

      activity_3 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          title: "Activity 3 - Multiple Objectives",
          content: %{
            "stem" => %{
              "content" => [
                %{
                  "type" => "p",
                  "children" => [%{"text" => "Explain the concept and solve the problem"}]
                }
              ]
            }
          },
          objectives: %{"1" => [objective_a.resource_id, sub_objective_a1.resource_id]}
        )

      activity_4 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          title: "Activity 4 - Different Objective",
          content: %{
            "stem" => %{
              "content" => [
                %{
                  "type" => "p",
                  "children" => [%{"text" => "What is the capital of France?"}]
                }
              ]
            }
          },
          objectives: %{"1" => [sub_objective_a1.resource_id]}
        )

      # Create pages with these activities
      page_1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 1 - Math Basics",
          graded: true,
          children: [],
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "id" => 1,
                "activity_id" => activity_1.resource_id
              }
            ]
          }
        )

      page_2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 2 - Advanced Math",
          graded: true,
          children: [],
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "id" => 2,
                "activity_id" => activity_2.resource_id
              },
              %{
                "type" => "activity-reference",
                "id" => 3,
                "activity_id" => activity_3.resource_id
              }
            ]
          }
        )

      page_3 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 3 - Geography",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "id" => 4,
                "activity_id" => activity_4.resource_id
              }
            ]
          }
        )

      # Create a root container revision
      root_container_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          title: "Root Container",
          children: [page_1.resource_id, page_2.resource_id, page_3.resource_id]
        )

      all_revisions =
        [
          objective_a,
          objective_b,
          sub_objective_a1,
          objective_without_activities,
          activity_1,
          activity_2,
          activity_3,
          activity_4,
          page_1,
          page_2,
          page_3,
          root_container_revision
        ]

      Enum.each(all_revisions, fn revision ->
        insert(:project_resource, %{
          project_id: project.id,
          resource_id: revision.resource_id
        })
      end)

      # Create publication
      publication =
        insert(:publication, %{
          project: project,
          root_resource_id: root_container_revision.resource_id
        })

      # Publish all resources
      Enum.each(all_revisions, fn revision ->
        insert(:published_resource, %{
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        })
      end)

      # Create a section with these pages
      section = insert(:section, type: :enrollable, base_project: project)

      # Create section resources - this is what makes the activities available to get_activities_for_objective
      {:ok, section} = Sections.create_section_resources(section, publication)
      {:ok, _} = Sections.rebuild_contained_pages(section)
      Sections.rebuild_contained_objectives(section)
      Sections.PostProcessing.apply(section, :all)

      # Enroll instructor in section
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      # Create some student attempts to make the activities show up with data
      student = insert(:user, %{can_create_sections: false})
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      # Create attempts for activities
      create_attempt(student, section, page_1, %{
        activity_1.resource_id => %{score: 1.0, out_of: 1.0}
      })

      create_attempt(student, section, page_2, %{
        activity_2.resource_id => %{score: 0.0, out_of: 1.0},
        activity_3.resource_id => %{score: 0.0, out_of: 1.0}
      })

      create_attempt(student, section, page_3, %{
        activity_4.resource_id => %{score: 1.0, out_of: 1.0}
      })

      %{
        section: section,
        objective_a: objective_a,
        objective_b: objective_b,
        sub_objective_a1: sub_objective_a1,
        objective_without_activities: objective_without_activities,
        activity_1: activity_1,
        activity_2: activity_2,
        activity_3: activity_3,
        activity_4: activity_4,
        page_1: page_1,
        page_2: page_2,
        page_3: page_3
      }
    end

    test "displays activities that have the specified objective attached", %{
      conn: conn,
      instructor: instructor,
      section: section,
      objective_a: objective_a,
      activity_1: activity_1,
      activity_3: activity_3
    } do
      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(conn, live_view_related_activities_route(section.slug, objective_a.resource_id))

      # Should show the objective title
      assert has_element?(view, "h1", objective_a.title)

      # Should show activities that have this objective attached
      # Activity 1 has objective_a
      assert has_element?(view, "td", activity_1.title)
      # Activity 3 has objective_a (and sub_objective_a1)
      assert has_element?(view, "td", activity_3.title)

      # Should not show activities that don't have this objective
      # Activity 2 has objective_b, not objective_a
      refute has_element?(view, "td", "Activity 2 - Advanced Math")
      # Activity 4 has sub_objective_a1, not objective_a
      refute has_element?(view, "td", "Activity 4 - Different Objective")
    end

    test "search functionality filters activities by question stem", %{
      conn: conn,
      instructor: instructor,
      section: section,
      objective_a: objective_a,
      activity_1: activity_1,
      activity_3: activity_3
    } do
      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(conn, live_view_related_activities_route(section.slug, objective_a.resource_id))

      # Should show the objective title
      assert has_element?(view, "h1", objective_a.title)

      # Should initially show both activities
      assert has_element?(view, "td", activity_1.title)
      assert has_element?(view, "td", activity_3.title)

      # Test search functionality - search for "2 + 2" (should match activity_1)
      view
      |> form("form[phx-change='search_activity']", %{activity_name: "2 + 2"})
      |> render_change()

      # Should still show the objective title
      assert has_element?(view, "h1", objective_a.title)

      # Should show activity_1 (contains "2 + 2")
      assert has_element?(view, "td", activity_1.title)
      # Should not show activity_3 (doesn't contain "2 + 2")
      refute has_element?(view, "td", activity_3.title)

      # Test search for "concept" (should match activity_3)
      view
      |> form("form[phx-change='search_activity']", %{activity_name: "concept"})
      |> render_change()

      # Should show activity_3 (contains "concept")
      assert has_element?(view, "td", activity_3.title)
      # Should not show activity_1 (doesn't contain "concept")
      refute has_element?(view, "td", activity_1.title)

      # Clear search - should show both activities again
      view
      |> form("form[phx-change='search_activity']", %{activity_name: ""})
      |> render_change()

      assert has_element?(view, "td", activity_1.title)
      assert has_element?(view, "td", activity_3.title)

      # Test search with no matches - should show message with search term
      view
      |> form("form[phx-change='search_activity']", %{activity_name: "nonexistent"})
      |> render_change()

      # Should show the no matches message with the search term
      assert has_element?(view, "p", "No activities found for nonexistent.")
      # Should not show any activities
      refute has_element?(view, "td", activity_1.title)
      refute has_element?(view, "td", activity_3.title)
    end

    test "shows no activities message when no activities are found", %{
      conn: conn,
      instructor: instructor,
      section: section,
      objective_without_activities: objective_without_activities
    } do
      # Create an objective that doesn't have any activities attached
      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(
          conn,
          live_view_related_activities_route(
            section.slug,
            objective_without_activities.resource_id
          )
        )

      assert has_element?(view, "h1", objective_without_activities.title)
      assert has_element?(view, "p", "No activities found for this learning objective.")
    end

    test "handles invalid objective ID", %{conn: conn, instructor: instructor, section: section} do
      conn = log_in_user(conn, instructor)

      assert {:error, {:redirect, %{to: redirect_to}}} =
               live(conn, live_view_related_activities_route(section.slug, 99999))

      assert String.contains?(redirect_to, "/insights/learning_objectives")
    end

    test "back navigation works correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      objective_a: objective_a
    } do
      conn = log_in_user(conn, instructor)

      # Define back parameters that should be preserved
      back_params = %{
        "offset" => "10",
        "limit" => "25",
        "sort_by" => "title",
        "sort_order" => "desc",
        "text_search" => "test search"
      }

      # Navigate to the related activities page with back_params
      {:ok, view, _html} =
        live(
          conn,
          live_view_related_activities_route(
            section.slug,
            objective_a.resource_id,
            %{"back_params" => Jason.encode!(back_params)}
          )
        )

      # Verify the back link includes the back_params
      back_link = view |> element("a[href*='/insights/learning_objectives']") |> render()

      # The back link should contain the encoded back_params
      assert back_link =~ "offset=10"
      assert back_link =~ "limit=25"
      assert back_link =~ "sort_by=title"
      assert back_link =~ "sort_order=desc"
      assert back_link =~ "text_search=test+search"

      # Extract the actual redirect URL from the back link to use in assert_redirect
      # The back link should contain the full URL with parameters
      back_url =
        back_link
        |> String.split("href=\"")
        |> Enum.at(1)
        |> String.split("\"")
        |> Enum.at(0)
        |> String.replace("&amp;", "&")

      # Click the back button and assert redirect to the URL with back_params
      view
      |> element("a[href*='/insights/learning_objectives']")
      |> render_click()

      assert_redirect(view, back_url)
    end

    test "displays activity data including attempts and scores", %{
      conn: conn,
      instructor: instructor,
      section: section,
      objective_a: objective_a,
      activity_1: activity_1,
      activity_3: activity_3
    } do
      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(conn, live_view_related_activities_route(section.slug, objective_a.resource_id))

      # Should show the objective title
      assert has_element?(view, "h1", objective_a.title)

      # Should show activities with their data
      assert has_element?(view, "td", activity_3.title)
      assert has_element?(view, "td", activity_1.title)

      # Assert on specific table row-column values
      # First row: Activity 3 - Multiple Objectives (attempts and % correct)
      # Attempts column
      assert has_element?(view, "tbody tr:first-child td:nth-child(2) span", "1")
      # % Correct column
      assert has_element?(view, "tbody tr:first-child td:nth-child(3) span", "0.0%")

      # Second row: Activity 1 - Basic Math (attempts and % correct)
      # Attempts column
      assert has_element?(view, "tbody tr:nth-child(2) td:nth-child(2) span", "1")
      # % Correct column
      assert has_element?(view, "tbody tr:nth-child(2) td:nth-child(3) span", "100.0%")
    end

    test "displays activities for sub-objectives", %{
      conn: conn,
      instructor: instructor,
      section: section,
      sub_objective_a1: sub_objective_a1,
      activity_3: activity_3,
      activity_4: activity_4
    } do
      conn = log_in_user(conn, instructor)

      {:ok, view, _html} =
        live(conn, live_view_related_activities_route(section.slug, sub_objective_a1.resource_id))

      # Should show the sub-objective title
      assert has_element?(view, "h1", sub_objective_a1.title)

      # Should show activities that have this sub-objective attached
      # Activity 3 has sub_objective_a1 (and objective_a)
      assert has_element?(view, "td", activity_3.title)
      # Activity 4 has sub_objective_a1
      assert has_element?(view, "td", activity_4.title)
    end
  end

  # Helper function for creating attempts
  # activities_data should be a map of activity_id => %{score: X, out_of: Y, revision: revision}
  # If an activity is not provided, it will get a score of 0
  defp create_attempt(
         student,
         section,
         page_revision,
         activities_data
       ) do
    resource_access = get_or_insert_resource_access(student, section, page_revision)

    # Get all activity references from the page
    page_activity_ids = Oli.Resources.activity_references(page_revision)

    # Create activity attempts for each activity in the page
    {activity_attempts, total_score, total_out_of} =
      page_activity_ids
      |> Enum.reduce({[], 0.0, 0.0}, fn activity_id, {attempts_acc, score_acc, out_of_acc} ->
        activity_data = Map.get(activities_data, activity_id, %{})

        activity_revision =
          activity_data[:revision] || get_activity_revision(section, activity_id)

        activity_score = activity_data[:score] || 0.0
        activity_out_of = activity_data[:out_of] || 0.0

        # Create activity attempt directly with the correct resource_id
        activity_attempt =
          %Oli.Delivery.Attempts.Core.ActivityAttempt{
            attempt_guid: Ecto.UUID.generate(),
            attempt_number: 1,
            lifecycle_state: activity_data[:lifecycle_state] || :evaluated,
            date_submitted: activity_data[:date_submitted] || ~U[2023-11-14 20:00:00Z],
            date_evaluated: activity_data[:date_evaluated] || ~U[2023-11-14 20:30:00Z],
            score: activity_score,
            out_of: activity_out_of,
            scoreable: activity_data[:scoreable] != false,
            transformed_model: activity_data[:transformed_model] || %{},
            # Use the original activity_id
            resource_id: activity_id,
            revision_id: activity_revision.id,
            inserted_at:
              activity_data[:inserted_at] || DateTime.utc_now() |> DateTime.truncate(:second)
          }
          |> Oli.Repo.insert!()

        {[activity_attempt | attempts_acc], score_acc + activity_score,
         out_of_acc + activity_out_of}
      end)

    # Create resource attempt with calculated scores
    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: page_revision,
        date_submitted: ~U[2023-11-14 20:00:00Z],
        date_evaluated: ~U[2023-11-14 20:30:00Z],
        score: total_score,
        out_of: total_out_of,
        lifecycle_state: :evaluated,
        content: %{model: []},
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    # Update activity attempts with the resource_attempt reference
    activity_attempts
    |> Enum.each(fn activity_attempt ->
      activity_attempt
      |> Ecto.Changeset.change(resource_attempt_id: resource_attempt.id)
      |> Oli.Repo.update!()
    end)

    %{resource_attempt: resource_attempt, activity_attempts: activity_attempts}
  end

  # Helper to get activity revision from section
  defp get_activity_revision(section, activity_id) do
    Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, activity_id)
  end

  defp get_or_insert_resource_access(student, section, revision) do
    Oli.Repo.get_by(
      Oli.Delivery.Attempts.Core.ResourceAccess,
      user_id: student.id,
      section_id: section.id,
      resource_id: revision.resource_id
    ) ||
      insert(:resource_access, %{
        user: student,
        section: section,
        resource: revision.resource
      })
  end
end
