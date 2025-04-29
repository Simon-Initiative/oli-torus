defmodule OliWeb.Delivery.Student.AssignmentsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp live_view_assignments_live_route(section_slug) do
    ~p"/sections/#{section_slug}/assignments"
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Start here",
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        graded: true
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        graded: true,
        purpose: :application
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id],
        title: "Configure your setup"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_2_revision.resource_id],
        title: "Building a Phoenix app"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          page_4_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        module_1_revision,
        module_2_revision,
        unit_1_revision,
        unit_2_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        analytics_version: :v2,
        certificate_enabled: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    certificate =
      insert(:certificate, %{
        section: section,
        assessments_apply_to: :custom,
        custom_assessments: [page_1_revision.resource_id],
        min_percentage_for_completion: 50,
        min_percentage_for_distinction: 80
      })

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      root_container: container_revision,
      certificate: certificate
    }
  end

  defp create_another_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Start here",
        graded: false
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        graded: false
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [unit_1_revision.resource_id],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        module_1_revision,
        unit_1_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "Another course!",
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      module_1: module_1_revision,
      unit_1: unit_1_revision,
      root_container: container_revision
    }
  end

  defp create_attempt(student, section, revision) do
    resource_access = get_or_insert_resource_access(student, section, revision)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: revision,
        date_submitted: ~U[2023-11-14 20:00:00Z],
        date_evaluated: ~U[2023-11-14 20:30:00Z],
        score: 5,
        out_of: 10,
        lifecycle_state: :evaluated,
        content: %{model: []}
      })

    resource_attempt
  end

  defp get_or_insert_resource_access(student, section, revision) do
    Oli.Repo.get_by(
      ResourceAccess,
      resource_id: revision.resource_id,
      section_id: section.id,
      user_id: student.id
    )
    |> case do
      nil ->
        insert(:resource_access, %{
          user: student,
          section: section,
          resource: revision.resource,
          score: 5,
          out_of: 10
        })

      resource_access ->
        resource_access
    end
  end

  def enroll_and_visit_section(%{user: user, section: section} = _attrs) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.mark_section_visited_for_student(section, user)
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, live_view_assignments_live_route(section.slug))

      assert redirect_path ==
               "/users/log_in"
    end
  end

  describe "not enrolled student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, live_view_assignments_live_route(section.slug))

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project, :enroll_and_visit_section]

    test "can access when enrolled to course", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      assert has_element?(view, "h1", "Assignments")
    end

    test "can navigate to an assignment", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      {:error, {:live_redirect, %{kind: :push, to: path}}} =
        view
        |> element(
          "div[role='assignment detail'][id='assignment_#{page_1.resource_id}'] a",
          "Start here"
        )
        |> render_click()

      assert path ==
               "/sections/#{section.slug}/lesson/#{page_1.slug}?request_path=%2Fsections%2F#{section.slug}%2Fassignments"
    end

    test "page icons correspond to the resource purpose and completed state", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      user: user
    } do
      _completed_page =
        create_attempt(user, section, page_2)

      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      # page 1 is required for the certificate, so we see it's asterisk icon

      assert element(
               view,
               "div[role='assignment detail'][id='assignment_#{page_1.resource_id}'] div[role='page icon'] svg"
             )
             |> render() =~ "asterisk icon"

      # page 2 is completed, so we see it's checked icon
      assert element(
               view,
               "div[role='assignment detail'][id='assignment_#{page_2.resource_id}'] div[role='page icon'] svg"
             )
             |> render() =~ "square checked icon"

      # and can see it's attempt summary
      assert has_element?(
               view,
               "div[role='assignment detail'][id='assignment_#{page_2.resource_id}'] span",
               "Attempt 1 of ∞"
             )

      assert has_element?(
               view,
               "div[role='assignment detail'][id='assignment_#{page_2.resource_id}'] span",
               "5 / 10"
             )

      assert element(
               view,
               "div[role='assignment detail'][id='assignment_#{page_3.resource_id}'] div[role='page icon'] svg"
             )
             |> render() =~ "flag icon"

      assert element(
               view,
               "div[role='assignment detail'][id='assignment_#{page_4.resource_id}'] div[role='page icon'] svg"
             )
             |> render() =~ "world icon"
    end

    test "can see completed pages summary", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      user: user
    } do
      _completed_page =
        create_attempt(user, section, page_1)

      _completed_page =
        create_attempt(user, section, page_2)

      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      assert has_element?(view, "span", "2 of 4 Assignments")
    end

    test "gets a `no assignments` message when there are not assignments to show", %{
      conn: conn,
      user: user
    } do
      %{section: section} = create_another_elixir_project(%{})

      enroll_and_visit_section(%{user: user, section: section})

      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      assert has_element?(view, "span", "There are no assignments")
    end

    test "can see certificate data when the section has a certificate", %{
      conn: conn,
      section: section,
      certificate: certificate
    } do
      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      assert has_element?(view, "#certificate_requirements", "This is a Certificate Course")

      assert has_element?(
               view,
               "#certificate_requirements span",
               "#{trunc(certificate.min_percentage_for_completion)}%"
             )

      assert has_element?(
               view,
               "#certificate_requirements span",
               "#{trunc(certificate.min_percentage_for_distinction)}%"
             )
    end

    test "filters required assignments for certificate", %{
      conn: conn,
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      {:ok, view, _html} = live(conn, live_view_assignments_live_route(section.slug))

      # assert all pages are displayed
      for page <- [page_1, page_2, page_3, page_4] do
        assert has_element?(
                 view,
                 "div[role='assignment detail'][id='assignment_#{page.resource_id}']"
               )
      end

      # open filter
      view
      |> element("button[phx-click=\"toggle_filter_open\"]")
      |> render_click()

      # select only required assignments
      view
      |> element("#select_required_option")
      |> render_click()

      # non-required pages are hidden
      for page <- [page_2, page_3, page_4] do
        refute has_element?(
                 view,
                 "div[role='assignment detail'][id='assignment_#{page.resource_id}']"
               )
      end

      # required page 1 is still displayed
      assert has_element?(
               view,
               "div[role='assignment detail'][id='assignment_#{page_1.resource_id}']"
             )
    end
  end
end
