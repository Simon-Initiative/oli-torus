defmodule OliWeb.CollaborationLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Resources.ResourceType
  alias OliWeb.CollaborationLive.CollabSpaceConfigView

  defp live_view_author_edit(project_slug, page_revision_slug),
    do: Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page_revision_slug)

  defp live_view_instructor_preview(section_slug, page_revision_slug),
    do: Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, page_revision_slug)

  defp live_view_collab_space_index(type, section_slug \\ []),
    do: Routes.collab_spaces_index_path(OliWeb.Endpoint, type, section_slug)

  defp create_project_and_section(_conn) do
    user = insert(:user)
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource = insert(:resource)
    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        title: "Other revision A"
      )
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    collab_space_config = build(:collab_space_config, status: :enabled)
    page_resource_cs = insert(:resource)
    page_revision_cs =
      insert(:revision,
        resource: page_resource_cs,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        slug: "page_revision_cs",
        collab_space_config: collab_space_config,
        title: "Other revision B"
      )
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_cs.id})

    container_resource = insert(:resource)
    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_resource.id, page_resource_cs.id],
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
      resource: page_resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_cs,
      revision: page_revision_cs,
      author: author
    })

    section = insert(:section, base_project: project, type: :enrollable)
    {:ok, _sr} = Sections.create_section_resources(section, publication)

    insert(:post, section: section, resource: page_resource_cs, user: user)
    second_post =
      insert(:post,
        status: :submitted,
        content: %{message: "Other post"},
        section: section,
        resource: page_resource_cs,
        user: user
      )

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      section: section,
      author: author,
      page_resource_cs: page_resource_cs,
      second_post: second_post
    ]
  end

  defp create_for_paging(project_id, publication, author, title) do
    collab_space_config = build(:collab_space_config, status: :enabled)

    page_resource_cs = insert(:resource)
    page_revision_cs =
      insert(:revision,
        resource: page_resource_cs,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        collab_space_config: collab_space_config,
        title: title
      )

    insert(:project_resource, %{project_id: project_id, resource_id: page_resource_cs.id})

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_cs,
      revision: page_revision_cs,
      author: author
    })
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project_and_section]

    test "redirects to new session when accessing the author edit page view", %{
      conn: conn,
      project: project,
      page_revision: page_revision
    } do
      assert conn
              |> get(live_view_author_edit(project.slug, page_revision.slug))
              |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fresource%2F#{page_revision.slug}\">redirected</a>"
    end

    test "returns forbidden when accessing the instructor preview page view", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      assert conn
              |> get(live_view_instructor_preview(section.slug, page_revision.slug))
              |> html_response(403)
    end

    test "redirects to new session when accessing the admin index view", %{
      conn: conn
    } do
      assert conn
              |> get(live_view_collab_space_index(:admin))
              |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fcollaborative_spaces\">redirected</a>"
    end

    test "redirects to new session when accessing the instructor index view", %{
      conn: conn,
      section: section
    } do
      assert conn
              |> get(live_view_collab_space_index(:instructor, section.slug))
              |> html_response(302) =~
              "You are being <a href=\"/session/new?request_path=%2Fsections%2F#{section.slug}%2Fcollaborative_spaces&amp;section=#{section.slug}\">redirected"
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn, :create_project_and_section]

    test "redirects to new session when accessing the author edit page view", %{
      conn: conn,
      project: project,
      page_revision: page_revision
    } do
      assert conn
              |> get(live_view_author_edit(project.slug, page_revision.slug))
              |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fresource%2F#{page_revision.slug}\">redirected</a>"
    end

    test "redirects to page when accessing the instructor preview page view", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      enroll_user_to_section(user, section, :context_learner)

      assert conn
              |> get(live_view_instructor_preview(section.slug, page_revision.slug))
              |> html_response(302) =~
              "You are being <a href=\"/sections/#{section.slug}/page/#{page_revision.slug}"
    end

    test "redirects to new session when accessing the admin index view", %{
      conn: conn
    } do
      assert conn
              |> get(live_view_collab_space_index(:admin))
              |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fcollaborative_spaces\">redirected</a>"
    end

    test "redirects to unauthorized when accessing the instructor index view", %{
      conn: conn,
      section: section,
      user: user
    } do
      enroll_user_to_section(user, section, :context_learner)

      assert conn
              |> get(live_view_collab_space_index(:instructor, section.slug))
              |> html_response(302) =~
              "You are being <a href=\"/unauthorized\">redirected"
    end
  end

  describe "user cannot access collab space config when is logged in as a instructor but is not preview" do
    setup [:user_conn, :create_project_and_section]

    test "returns just the page when accessing the view", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      enroll_user_to_section(user, section, :context_instructor)

      conn = get(conn, Routes.page_delivery_path(conn, :page, section.slug, page_revision.slug))
      refute html_response(conn, 200) =~ "<div class=\"card-title h5\">Collaborative Space</div>"
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin or author of the project" do
    setup [:author_conn, :create_project_and_section]

    test "redirects to projects when accessing the admin index view", %{
      conn: conn
    } do
      assert conn
              |> get(live_view_collab_space_index(:admin))
              |> response(403) =~
              "Forbidden"
    end

    test "redirects to projects when accessing the author edit page view", %{
      conn: conn,
      project: project,
      page_revision: page_revision
    } do
      assert conn
              |> get(live_view_author_edit(project.slug, page_revision.slug))
              |> html_response(302) =~
              "You are being <a href=\"/authoring/projects\">redirected</a>"
    end
  end

  describe "user can access when is logged in as an author, is not a system admin but is author of the project" do
    setup [:create_project_and_section]

    test "returns the collab space config", %{
      conn: conn,
      author: author,
      project: project,
      page_revision: page_revision
    } do
      conn =
        conn
        |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
        |> get(live_view_author_edit(project.slug, page_revision.slug))

      assert html_response(conn, 200) =~ "<div class=\"card-title h5\">Collaborative Space</div>"
    end
  end

  describe "instructor - collab space config view" do
    setup [:lms_instructor_conn, :create_project_and_section]

    test "returns the collab space config as disabled when no config and change status correctly",
        %{conn: conn, instructor: instructor, section: section, page_revision: page_revision} do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision.collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Disabled")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      refute has_element?(view, "button[phx-click=\"archive\"", "Archived")
      refute has_element?(view, "#revision_collab_space_config_threaded")

      view
      |> element("button[phx-click=\"enable\"")
      |> render_click()

      assert has_element?(view, "span", "Enabled")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
      assert has_element?(view, "button[phx-click=\"archive\"", "Archive")
    end

    test "returns the collab space config as enabled when there is config in the page and change status correctly",
        %{
          conn: conn,
          instructor: instructor,
          section: section,
          page_revision_cs: page_revision_cs
        } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision_cs.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Enabled")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
      assert has_element?(view, "button[phx-click=\"archive\"", "Archive")

      view
      |> element("button[phx-click=\"archive\"")
      |> render_click()

      assert has_element?(view, "span", "Archived")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")

      view
      |> element("button[phx-click=\"disable\"")
      |> render_click()

      assert has_element?(view, "span", "Disabled")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      refute has_element?(view, "button[phx-click=\"archive\"", "Archived")
    end

    test "returns the collab space config as archived when there is a delivery setting config", %{
      conn: conn,
      instructor: instructor,
      section: section,
      page_revision_cs: page_revision_cs,
      page_resource_cs: page_resource_cs
    } do
      collab_space_config = build(:collab_space_config, status: :archived)

      insert(:delivery_setting,
        user: instructor,
        section: section,
        resource: page_resource_cs,
        collab_space_config: collab_space_config
      )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision_cs.slug
          }
        )

      assert has_element?(view, "span", "Archived")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
    end

    test "shows the collab space config attrs correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision_cs.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Enabled")

      assert view
              |> element("#delivery_setting_collab_space_config_threaded")
              |> render() =~ "checked"

      assert view
              |> element("#delivery_setting_collab_space_config_auto_accept")
              |> render() =~ "checked"

      assert view
            |> element("#delivery_setting_collab_space_config_show_full_history")
            |> render() =~ "checked"

      assert view
            |> element("#delivery_setting_collab_space_config_participation_min_replies")
            |> render() =~ "0"

      assert view
            |> element("#delivery_setting_collab_space_config_participation_min_posts")
            |> render() =~ "0"
    end

    test "changes the collab space config attrs correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      page_revision_cs: page_revision_cs,
      page_resource_cs: page_resource_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision_cs.slug
          }
        )

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        delivery_setting: %{
          collab_space_config: %{
            threaded: false,
            auto_accept: false,
            participation_min_replies: 2
          }
        }
      })

      refute view
              |> element("#delivery_setting_collab_space_config_threaded")
              |> render() =~ "checked"

      refute view
              |> element("#delivery_setting_collab_space_config_auto_accept")
              |> render() =~ "checked"

      assert view
            |> element("#delivery_setting_collab_space_config_participation_min_replies")
            |> render() =~ "2"

      assert %DeliverySetting{
              collab_space_config: %{
                participation_min_replies: 2,
                auto_accept: false,
                threaded: false
              }
            } =
              Delivery.get_delivery_setting_by(%{
                section_id: section.id,
                resource_id: page_resource_cs.id
              })
    end

    test "handles error when changes to the collab space config attrs are wrong", %{
      conn: conn,
      instructor: instructor,
      section: section,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "is_delivery" => true,
            "page_slug" => page_revision_cs.slug
          }
        )

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        delivery_setting: %{collab_space_config: %{participation_min_replies: -1}}
      })

      refute view
            |> element("#delivery_setting_collab_space_config_participation_min_replies")
            |> render() =~ "-1"

      assert view
            |> element("#delivery_setting_collab_space_config_participation_min_replies")
            |> render() =~ "0"
    end
  end

  describe "admin - collab space config view" do
    setup [:admin_conn, :create_project_and_section]

    test "returns the collab space config as disabled when no config and change status correctly",
        %{conn: conn, author: author, project: project, page_revision: page_revision} do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_author_id" => author.id,
            "collab_space_config" => page_revision.collab_space_config,
            "project_slug" => project.slug,
            "page_slug" => page_revision.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Disabled")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      refute has_element?(view, "button[phx-click=\"archive\"", "Archived")
      refute has_element?(view, "#revision_collab_space_config_threaded")

      view
      |> element("button[phx-click=\"enable\"")
      |> render_click()

      assert has_element?(view, "span", "Enabled")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
      assert has_element?(view, "button[phx-click=\"archive\"", "Archive")
    end

    test "returns the collab space config as enabled when there is config and change status correctly",
        %{conn: conn, author: author, project: project, page_revision_cs: page_revision_cs} do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_author_id" => author.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "project_slug" => project.slug,
            "page_slug" => page_revision_cs.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Enabled")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
      assert has_element?(view, "button[phx-click=\"archive\"", "Archive")

      view
      |> element("button[phx-click=\"archive\"")
      |> render_click()

      assert has_element?(view, "span", "Archived")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")

      view
      |> element("button[phx-click=\"disable\"")
      |> render_click()

      assert has_element?(view, "span", "Disabled")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      refute has_element?(view, "button[phx-click=\"archive\"", "Archived")
    end

    test "shows the collab space config attrs correctly", %{
      conn: conn,
      author: author,
      project: project,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_author_id" => author.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "project_slug" => project.slug,
            "page_slug" => page_revision_cs.slug
          }
        )

      assert has_element?(view, ".h5", "Collaborative Space")
      assert has_element?(view, "span", "Enabled")

      assert view |> element("#revision_collab_space_config_threaded") |> render() =~ "checked"
      assert view |> element("#revision_collab_space_config_auto_accept") |> render() =~ "checked"

      assert view |> element("#revision_collab_space_config_show_full_history") |> render() =~
              "checked"

      assert view
            |> element("#revision_collab_space_config_participation_min_replies")
            |> render() =~ "0"

      assert view |> element("#revision_collab_space_config_participation_min_posts") |> render() =~
              "0"
    end

    test "changes the collab space config attrs correctly", %{
      conn: conn,
      author: author,
      project: project,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_author_id" => author.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "project_slug" => project.slug,
            "page_slug" => page_revision_cs.slug
          }
        )

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        revision: %{
          collab_space_config: %{
            threaded: false,
            auto_accept: false,
            participation_min_replies: 2
          }
        }
      })

      refute view |> element("#revision_collab_space_config_threaded") |> render() =~ "checked"
      refute view |> element("#revision_collab_space_config_auto_accept") |> render() =~ "checked"

      assert view
              |> element("#revision_collab_space_config_participation_min_replies")
              |> render() =~ "2"
    end

    test "handles error when changes to the collab space config attrs are wrong", %{
      conn: conn,
      author: author,
      project: project,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceConfigView,
          session: %{
            "current_author_id" => author.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "project_slug" => project.slug,
            "page_slug" => page_revision_cs.slug
          }
        )

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{revision: %{collab_space_config: %{participation_min_replies: -1}}})

      refute view
              |> element("#revision_collab_space_config_participation_min_replies")
              |> render() =~ "-1"

      assert view
              |> element("#revision_collab_space_config_participation_min_replies")
              |> render() =~ "0"
    end
  end

  describe "admin - index view" do
    setup [:admin_conn, :create_project_and_section]

    test "loads correctly", %{
      conn: conn,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:admin))

      assert has_element?(view, "#collaborative-spaces-table")
      assert has_element?(view, "td", "#{project.title}")
      assert has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "2")
      assert has_element?(view, "td", "#{page_revision.title}")
    end

    test "applies searching", %{
      conn: conn,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs
    } do
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:admin))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "other revision A"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      refute has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "#{page_revision.title}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "#{page_revision.title}")
    end

    test "applies sorting", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:admin))

      assert view
              |> element("tr:first-child > td:nth-child(2)")
              |> render() =~
              "Other revision A"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "page_title"})

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "page_title"})

      assert view
              |> element("tr:first-child > td:nth-child(2)")
              |> render() =~
              "Other revision B"
    end

    test "applies paging", %{
      conn: conn,
      project: project,
      publication: publication,
      author: author
    } do
      for i <- 0..20 do
        create_for_paging(project.id, publication, author, "Page #{i}")
      end

      {:ok, view, _html} = live(conn, live_view_collab_space_index(:admin))

      assert view
              |> element("tr:first-child > td:nth-child(2)")
              |> render() =~
              "Other revision A"

      assert view
              |> element("tr:nth-child(2) > td:nth-child(2)")
              |> render() =~
              "Other revision B"

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute view
              |> element("tr:first-child > td:nth-child(2)")
              |> render() =~
              "Other revision A"

      refute view
              |> element("tr:nth-child(2) > td:nth-child(2)")
              |> render() =~
              "Other revision B"
    end

    test "renders datetimes using the local timezone", context = %{second_post: second_post} do
      {:ok, conn: conn, context: session_context} = set_timezone(context)

      {:ok, view, _html} = live(conn, live_view_collab_space_index(:admin))

      assert has_element?(
              view,
              "tr",
              OliWeb.Common.Utils.render_date(second_post, :inserted_at, session_context)
            )
    end
  end

  describe "instructor - index view" do
    setup [:user_conn, :create_project_and_section]

    test "loads correctly", %{
      conn: conn,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      user: user,
      section: section
    } do
      enroll_user_to_section(user, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:instructor, section.slug))

      assert has_element?(view, "#collaborative-spaces-table")
      assert has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "2")
      assert has_element?(view, "td", "#{page_revision.title}")
    end

    test "applies searching", %{
      conn: conn,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      section: section,
      user: user
    } do
      enroll_user_to_section(user, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:instructor, section.slug))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "other revision A"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      refute has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "#{page_revision.title}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "td", "#{page_revision_cs.title}")
      assert has_element?(view, "td", "#{page_revision.title}")
    end

    test "applies sorting", %{
      conn: conn,
      section: section,
      user: user
    } do
      enroll_user_to_section(user, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_collab_space_index(:instructor, section.slug))

      assert view
              |> element("tr:first-child > td:first-child")
              |> render() =~
              "Other revision A"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "page_title"})

      assert view
              |> element("tr:first-child > td:first-child")
              |> render() =~
              "Other revision B"
    end

    test "applies paging", %{
      conn: conn,
      project: project,
      publication: publication,
      author: author,
      user: user
    } do
      for i <- 0..20 do
        create_for_paging(project.id, publication, author, "Page #{i}")
      end

      section = insert(:section, base_project: project, type: :enrollable)
      {:ok, _sr} = Sections.create_section_resources(section, publication)
      enroll_user_to_section(user, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_collab_space_index(:instructor, section.slug))

      assert view
              |> element("tr:first-child > td:first-child")
              |> render() =~
              "Other revision A"

      assert view
              |> element("tr:nth-child(2) > td:first-child")
              |> render() =~
              "Other revision B"

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute view
              |> element("tr:first-child > td:first-child")
              |> render() =~
              "Other revision A"

      refute view
              |> element("tr:nth-child(2) > td:first-child")
              |> render() =~
              "Other revision B"
    end
  end
end
