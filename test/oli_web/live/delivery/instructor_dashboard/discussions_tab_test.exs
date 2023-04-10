defmodule OliWeb.Delivery.InstructorDashboard.DiscussionsTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes

  defp live_view_discussions_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :discussions
    )
  end

  defp create_section(_conn) do
    user = insert(:user)
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource_1 = insert(:resource)
    collab_space_config_1 = build(:collab_space_config, status: :enabled)

    page_revision_1 =
      insert(:revision,
        resource: page_resource_1,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        slug: "page_1",
        collab_space_config: collab_space_config_1,
        title: "Page #1"
      )

    page_resource_2 = insert(:resource)
    collab_space_config_2 = build(:collab_space_config, status: :enabled)

    page_revision_2 =
      insert(:revision,
        resource: page_resource_2,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        slug: "page_2",
        collab_space_config: collab_space_config_2,
        title: "Page #2"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_1.id})
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_2.id})

    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_resource_1.id, page_resource_2.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_1,
      revision: page_revision_1,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_2,
      revision: page_revision_2,
      author: author
    })

    section = insert(:section, base_project: project, type: :enrollable)
    {:ok, _sr} = Sections.create_section_resources(section, publication)

    page_1_post_1 =
      insert(:post,
        status: :approved,
        content: %{message: "Page 1 - approved post"},
        section: section,
        resource: page_resource_1,
        user: user
      )

    page_1_post_2 =
      insert(:post,
        status: :submitted,
        content: %{message: "Page 1 - pending approval post"},
        section: section,
        resource: page_resource_1,
        user: user
      )

    page_1_post_3 =
      insert(:post,
        status: :approved,
        content: %{message: "Page 1 - answered post"},
        section: section,
        resource: page_resource_1,
        user: user
      )

    page_1_post_4 =
      insert(:post,
        status: :approved,
        parent_post: page_1_post_3,
        content: %{message: "Page 1 - answering post"},
        section: section,
        resource: page_resource_1,
        user: user
      )

    page_2_post_1 =
      insert(:post,
        status: :submitted,
        content: %{message: "Page 2 - pending approval post"},
        section: section,
        resource: page_resource_2,
        user: user
      )

    [
      project: project,
      publication: publication,
      page_revision_1: page_revision_1,
      page_revision_2: page_revision_2,
      section: section,
      author: author,
      page_1_post_1: page_1_post_1,
      page_1_post_2: page_1_post_2,
      page_1_post_3: page_1_post_3,
      page_1_post_4: page_1_post_4,
      page_2_post_1: page_2_post_1
    ]
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fdiscussions"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_discussions_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_discussions_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :create_section]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_discussions_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_discussions_route(section.slug))

      assert has_element?(view, "h4", "Discussion Activity")
      assert has_element?(view, "small", "Filter by")
    end

    test "shows all posts by default", %{conn: conn, instructor: instructor, section: section} do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_discussions_route(section.slug))

      assert has_element?(view, "option[value='all'][selected]")
      assert has_element?(view, "div", "Showing all results (5 total)")
      assert get_elements_in_table_count(view) == 5
    end

    test "filters by posts that need approval", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_discussions_route(section.slug))

      view |> element("form[phx-change='filter']") |> render_change(%{filter: "need_approval"})

      assert get_elements_in_table_count(view) == 2
      refute view |> has_element?("p", "Page 1 - approved post")
    end

    test "filters by posts that need a response", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_discussions_route(section.slug))

      view |> element("form[phx-change='filter']") |> render_change(%{filter: "need_response"})

      assert get_elements_in_table_count(view) == 3
      refute view |> has_element?("p", "Page 1 - answered post")
    end

    test "filters by collab space", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_discussions_route(section.slug))

      view |> element("form[phx-change='filter']") |> render_change(%{filter: "by_discussion"})

      assert get_elements_in_table_count(view) == 2
      assert view |> has_element?("span", "Page #1")
      assert view |> has_element?("p", "Number of posts: 4 (1 pending approval)")
      assert view |> has_element?("span", "Page #2")
      assert view |> has_element?("p", "Number of posts: 1 (1 pending approval)")
    end

    defp get_elements_in_table_count(view) do
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find("#discussion_activity_table td")
      |> length()
    end
  end
end
