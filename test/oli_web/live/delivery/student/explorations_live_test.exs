defmodule OliWeb.Delivery.Student.ExplorationsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## exploration pages...
    exploration_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "A Great Exploration",
        graded: true,
        duration_minutes: 10,
        purpose: :application
      )

    exploration_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Another Great Exploration",
        duration_minutes: 10,
        purpose: :application
      )

    orphan_exploration_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Orphan Exploration",
        duration_minutes: 10,
        purpose: :application,
        relates_to: [exploration_1_revision.resource_id]
      )

    basic_exploration_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Basic Exploration Page",
        duration_minutes: 10,
        purpose: :application,
        graded: true
      )

    adaptive_exploration_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Adaptive Exploration Page",
        duration_minutes: 10,
        purpose: :application,
        graded: true,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false
        }
      )

    non_exploration_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Non Exploration Page",
        duration_minutes: 10,
        purpose: :foundation,
        graded: true
      )

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [exploration_1_revision.resource_id, exploration_2_revision.resource_id],
        title: "Introduction"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          basic_exploration_revision.resource_id,
          adaptive_exploration_revision.resource_id,
          non_exploration_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        exploration_1_revision,
        exploration_2_revision,
        basic_exploration_revision,
        adaptive_exploration_revision,
        non_exploration_revision,
        orphan_exploration_revision,
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
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    section = Oli.Delivery.Sections.PostProcessing.apply(section, :all)

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      container: container_revision,
      exploration_1: exploration_1_revision,
      exploration_2: exploration_2_revision,
      basic_exploration: basic_exploration_revision,
      adaptive_exploration: adaptive_exploration_revision,
      orphan_exploration: orphan_exploration_revision,
      non_exploration: non_exploration_revision
    }
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, ~p"/sections/#{section.slug}/explorations")

      assert redirect_path ==
               "/users/log_in"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, ~p"/sections/#{section.slug}/explorations")

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end

    test "can access when enrolled to course", %{conn: conn, user: user, section: section} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/explorations")

      assert has_element?(view, "h1", "Your Explorations")
      assert has_element?(view, "h2", "Unit 1: Introduction")
      assert has_element?(view, "h5", "A Great Exploration")
      assert has_element?(view, "h5", "Another Great Exploration")
    end

    test "can navigate to an exploration page", %{
      conn: conn,
      user: user,
      section: section,
      exploration_1: exploration_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/explorations")

      view
      |> element("div[id=exploration_card_#{exploration_1.id}] a", "Let's Begin")
      |> render_click()

      assert_redirected(
        view,
        "/sections/#{section.slug}/lesson/#{exploration_1.slug}?request_path=%2Fsections%2F#{section.slug}%2Fexplorations"
      )

      # the redirected page will show the prologue or go directly to the exploration
      # if there is an attempt in progress
    end

    test "pages that belong to the root container are shown correctly in the explorations tab", %{
      conn: conn,
      user: user,
      section: section,
      basic_exploration: basic_exploration,
      adaptive_exploration: adaptive_exploration,
      container: container
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/explorations")

      # assert the container title and the pages belonging to the container are shown
      assert has_element?(view, "h2", "Curriculum 1: #{container.title}")
      assert has_element?(view, "h5", basic_exploration.title)
      assert has_element?(view, "h5", adaptive_exploration.title)
    end

    test "orphaned pages are shown correctly in the explorations tab", %{
      conn: conn,
      user: user,
      section: section,
      orphan_exploration: orphan_exploration
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/explorations")

      # assert the container title and the orphaned pages are shown
      assert has_element?(view, "h2", "Other Pages")
      assert has_element?(view, "h5", orphan_exploration.title)
    end

    test "a non exploration page is not shown in the explorations tab", %{
      conn: conn,
      user: user,
      section: section,
      non_exploration: non_exploration
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/explorations")

      refute has_element?(view, "h5", non_exploration.title)
    end
  end
end
