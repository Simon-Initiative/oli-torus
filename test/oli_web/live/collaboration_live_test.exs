defmodule OliWeb.CollaborationLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Resources.{Collaboration, ResourceType}
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration.Post, as: PostSchema
  alias OliWeb.CollaborationLive.{CollabSpaceView, CollabSpaceConfigView}
  alias OliWeb.Presence

  defp live_view_author_edit(project_slug, page_revision_slug),
    do: Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page_revision_slug)

  defp live_view_instructor_preview(section_slug, page_revision_slug),
    do:
      Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, page_revision_slug)

  defp live_view_collab_space_index(type, section_slug \\ []),
    do: Routes.collab_spaces_index_path(OliWeb.Endpoint, type, section_slug)

  defp live_view_student_page(section_slug, page_revision_slug),
    do: Routes.page_delivery_path(OliWeb.Endpoint, :page, section_slug, page_revision_slug)

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

    first_post = insert(:post, section: section, resource: page_resource_cs, user: user)

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
      first_post: first_post,
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

    test "redirects to new session when accessing the student collab space page view", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      assert conn
             |> get(live_view_student_page(section.slug, page_revision.slug))
             |> html_response(302) =~
               "You are being <a href=\"/session/new?request_path=%2Fsections%2F#{section.slug}%2Fpage%2F#{page_revision.slug}&amp;section=#{section.slug}\">redirected"
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

    test "returns not authorized when accessing the student collab space page view not being enrolled in the section",
         %{
           conn: conn,
           section: section,
           page_revision: page_revision
         } do
      assert conn
             |> get(live_view_student_page(section.slug, page_revision.slug))
             |> html_response(200) =~
               "Not authorized"
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

      assert html_response(conn, 200) =~
               "<h3 class=\"card-title\">Collaborative Space Config</h3>"
    end
  end

  describe "user can access when is logged in as a system admin" do
    setup [:admin_conn, :create_project_and_section]

    test "returns the collab space view when accessing the instructor preview page view", %{
      conn: conn,
      admin: admin,
      section: section,
      page_revision_cs: page_revision_cs
    } do
      conn =
        conn
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))
        |> get(live_view_instructor_preview(section.slug, page_revision_cs.slug))

      assert html_response(conn, 200) =~ "<h3 class=\"text-xl font-bold\">Discussion</h3>"
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

      assert has_element?(view, "h3", "Collaborative Space Config")
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

      assert_receive {:updated_collab_space_config, %CollabSpaceConfig{status: :enabled}}
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

      assert has_element?(view, "h3", "Collaborative Space Config")
      assert has_element?(view, "span", "Enabled")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")
      assert has_element?(view, "button[phx-click=\"archive\"", "Archive")

      view
      |> element("button[phx-click=\"archive\"")
      |> render_click()

      assert has_element?(view, "span", "Archived")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      assert has_element?(view, "button[phx-click=\"disable\"", "Disable")

      assert_receive {:updated_collab_space_config, %CollabSpaceConfig{status: :archived}}

      view
      |> element("button[phx-click=\"disable\"")
      |> render_click()

      assert has_element?(view, "span", "Disabled")
      assert has_element?(view, "button[phx-click=\"enable\"", "Enable")
      refute has_element?(view, "button[phx-click=\"archive\"", "Archived")

      assert_receive {:updated_collab_space_config, %CollabSpaceConfig{status: :disabled}}
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

      assert has_element?(view, "h3", "Collaborative Space Config")
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
             |> element("#delivery_setting_collab_space_config_anonymous_posting")
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
            participation_min_replies: 2,
            anonymous_posting: false
          }
        }
      })

      refute view
             |> element("#delivery_setting_collab_space_config_threaded")
             |> render() =~ "checked"

      refute view
             |> element("#delivery_setting_collab_space_config_auto_accept")
             |> render() =~ "checked"

      refute view
             |> element("#delivery_setting_collab_space_config_anonymous_posting")
             |> render() =~ "checked"

      assert view
             |> element("#delivery_setting_collab_space_config_participation_min_replies")
             |> render() =~ "2"

      assert %DeliverySetting{
               collab_space_config: %{
                 participation_min_replies: 2,
                 auto_accept: false,
                 threaded: false,
                 anonymous_posting: false
               }
             } =
               Delivery.get_delivery_setting_by(%{
                 section_id: section.id,
                 resource_id: page_resource_cs.id
               })

      assert_receive {
        :updated_collab_space_config,
        %CollabSpaceConfig{
          threaded: false,
          auto_accept: false,
          participation_min_replies: 2
        }
      }
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

      refute_receive {:updated_collab_space_config, _}
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

      assert has_element?(view, "h3", "Collaborative Space Config")
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

      refute_receive {:updated_collab_space_config, _}
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

      assert has_element?(view, "h3", "Collaborative Space Config")
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

      assert has_element?(view, "h3", "Collaborative Space Config")
      assert has_element?(view, "span", "Enabled")

      assert view |> element("#revision_collab_space_config_threaded") |> render() =~ "checked"
      assert view |> element("#revision_collab_space_config_auto_accept") |> render() =~ "checked"

      assert view |> element("#revision_collab_space_config_show_full_history") |> render() =~
               "checked"

      assert view |> element("#revision_collab_space_config_anonymous_posting") |> render() =~
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
            participation_min_replies: 2,
            anonymous_posting: false
          }
        }
      })

      refute view |> element("#revision_collab_space_config_threaded") |> render() =~ "checked"
      refute view |> element("#revision_collab_space_config_auto_accept") |> render() =~ "checked"

      refute view |> element("#revision_collab_space_config_anonymous_posting") |> render() =~
               "checked"

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

  describe "student - collab space view" do
    setup [:user_conn, :create_project_and_section]

    test "displays the collab space",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           first_post: first_post
         } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "h3", "Discussion")
      assert has_element?(view, "h3", "Active users (1)")
      assert has_element?(view, ".post-index", "#1")
      assert has_element?(view, ".post-content", "#{first_post.content.message}")
    end

    test "presence",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      test_user = insert(:user, name: "Test User")

      Presence.track_presence(
        self(),
        CollabSpaceView.channels_topic(section.slug, page_revision_cs.resource_id),
        test_user.id,
        CollabSpaceView.presence_default_user_payload(test_user)
      )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      other_test_user = insert(:user, name: "Other Test User")

      Presence.track_presence(
        self(),
        CollabSpaceView.channels_topic(section.slug, page_revision_cs.resource_id),
        other_test_user.id,
        CollabSpaceView.presence_default_user_payload(other_test_user)
      )

      send(view.pid, %{event: "presence_diff"})

      assert has_element?(view, "h3", "Active users (3)")
      assert has_element?(view, ".collab-space__active-users li", "#{user.name}")
      assert has_element?(view, ".collab-space__active-users li", "#{test_user.name}")
      assert has_element?(view, ".collab-space__active-users li", "#{other_test_user.name}")
    end

    test "sorting",
         %{
           conn: conn,
           user: user,
           section: section,
           page_resource_cs: page_resource_cs,
           page_revision_cs: page_revision_cs,
           first_post: first_post
         } do
      test_post = insert(:post, user: user, section: section, resource: page_resource_cs)

      insert(:post,
        user: user,
        section: section,
        resource: page_resource_cs,
        parent_post: test_post
      )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "#postsList > div:first-of-type", "#{first_post.content.message}")
      assert has_element?(view, "#postsList > div:nth-child(2)", "#{test_post.content.message}")

      view
      |> element("button[phx-value-sort_by=\"replies_count\"")
      |> render_click(%{"sort_by" => "replies_count", "sort_order" => "desc"})

      assert has_element?(view, "#postsList > div:first-child", "#{test_post.content.message}")
      assert has_element?(view, "#postsList > div:nth-child(2)", "#{first_post.content.message}")
    end

    test "creating a post",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      message = "Testing post"

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{message: message}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      assert length(posts) == 2

      assert has_element?(view, ".post-index", "#2")
      assert has_element?(view, ".post-content", "#{message}")
    end

    test "creating an anonymous post",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      message = "Testing anonymous post"

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      [initial_post] =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      refute render(view) =~ "(Me as Anonymous user)"

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{message: message}, anonymous: true}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      anonymous_post = Enum.find(posts, &(&1.id != initial_post.id))

      assert length(posts) == 2

      assert anonymous_post.content.message == message
      assert anonymous_post.anonymous

      assert has_element?(view, ".post-index", "#2")
      assert has_element?(view, ".post-content", "#{message}")
      assert render(view) =~ "(Me as Anonymous user)"
    end

    test "create post displays error message",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{other_key: "Testing post"}}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Couldn&#39;t create post"

      refute_receive {:post_created, %PostSchema{}}
    end

    test "editing a post",
         %{
           conn: conn,
           user: user,
           section: section,
           page_resource_cs: page_resource_cs,
           page_revision_cs: page_revision_cs
         } do
      content = build(:post_content, message: "New post")

      new_post_1 =
        insert(:post, user: user, section: section, resource: page_resource_cs, content: content)

      new_post_2 = insert(:post, section: section, resource: page_resource_cs)

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      refute has_element?(
               view,
               "button[phx-click=\"set_editing_post\"][phx-value-post_id=\"#{new_post_2.id}\"]"
             )

      assert has_element?(view, ".post-content", "#{new_post_1.content.message}")

      view
      |> element("button[phx-click=\"set_editing_post\"][phx-value-post_id=\"#{new_post_1.id}\"]")
      |> render_click()

      view
      |> element("form#edit_post_form_#{new_post_1.id}")
      |> render_submit(%{"post" => %{content: %{message: "Another text"}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      assert_receive {:post_edited, %PostSchema{}}

      updated_post =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )
        |> Enum.find(&(&1.id == new_post_1.id))

      assert has_element?(view, ".post-content", "#{updated_post.content.message}")
      refute has_element?(view, ".post-content", "#{new_post_1.content.message}")
    end

    test "deleting a post",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      content = build(:post_content, message: "Testing")

      %PostSchema{id: post_id} =
        post =
        insert(:post, user: user, section: section, resource: page_resource_cs, content: content)

      parent_post = insert(:post, user: user, section: section, resource: page_resource_cs)

      insert(:post,
        user: user,
        section: section,
        resource: page_resource_cs,
        parent_post: parent_post,
        thread_root: parent_post
      )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      refute has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{first_post.id}\"]"
             )

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{parent_post.id}\"]:disabled"
             )

      assert has_element?(view, ".post-content", "#{post.content.message}")

      view
      |> element("button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{post_id}\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete_posts\"")
      |> render_click()

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post/s successfully deleted"

      assert_receive {:post_deleted, ^post_id}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      assert length(posts) == 3

      refute has_element?(view, ".post-content", "#{post.content.message}")
    end

    test "creating a reply",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           first_post: first_post
         } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      view
      |> element("form#reply_form_#{first_post.id}")
      |> render_submit(%{"post" => %{content: %{message: "Testing reply"}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      reply = Enum.find(posts, &(&1.thread_root_id == first_post.id))
      assert length(posts) == 2

      expand_replies(view, first_post.id)

      assert has_element?(view, ".post-content", "#{reply.content.message}")
    end

    test "editing a reply",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      content = build(:post_content, message: "Other test")

      reply =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          content: content,
          parent_post: first_post,
          thread_root: first_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      expand_replies(view, first_post.id)

      view
      |> element("button[phx-click=\"set_editing_post\"][phx-value-post_id=\"#{reply.id}\"]")
      |> render_click()

      view
      |> element("form#edit_post_form_#{reply.id}}")
      |> render_submit(%{"post" => %{content: %{message: "Testing reply"}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      assert_receive {:post_edited, %PostSchema{}}

      updated_reply =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )
        |> Enum.find(&(&1.id == reply.id))

      refute has_element?(view, ".post-content", "#{reply.content.message}")
      assert has_element?(view, ".post-content", "#{updated_reply.content.message}")
    end

    test "deleting a reply",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs
         } do
      content = build(:post_content, message: "Testing")
      parent_post = insert(:post, user: user, section: section, resource: page_resource_cs)

      %PostSchema{id: reply_id} =
        reply =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          content: content,
          parent_post: parent_post,
          thread_root: parent_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      expand_replies(view, parent_post.id)

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{parent_post.id}\"]:disabled"
             )

      assert has_element?(view, ".post-content", "#{reply.content.message}")

      view
      |> element("button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{reply_id}\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete_posts\"")
      |> render_click()

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post/s successfully deleted"

      assert_receive {:post_deleted, ^reply_id}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      assert length(posts) == 2

      refute has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{parent_post.id}\"]:disabled"
             )

      refute has_element?(view, ".post-content", "#{reply.content.message}")
    end

    test "creating a reply of a reply",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      reply =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          parent_post: first_post,
          thread_root: first_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      expand_replies(view, first_post.id)

      view
      |> element("form#reply_form_#{reply.id}")
      |> render_submit(%{"post" => %{content: %{message: "Testing reply"}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )

      reply_reply = Enum.find(posts, &(&1.parent_post_id == reply.id))
      assert length(posts) == 3

      assert has_element?(view, ".post-content", "#{reply_reply.content.message}")
      assert has_element?(view, ".reply-info", "Replying to #1.1")
    end

    test "collab space is archived",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      collab_space_config = build(:collab_space_config, status: :archived)

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "h3", "Discussion")
      assert has_element?(view, "span", "Archived")
      assert has_element?(view, "form#new_post_form button[type=submit]:disabled")
      assert has_element?(view, ".readonly")
    end

    test "post is archived",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs
         } do
      post =
        insert(:post, user: user, section: section, resource: page_resource_cs, status: :archived)

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "#post_#{post.id}.readonly")
    end

    test "reply is archived",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      reply =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          thread_root: first_post,
          parent_post: first_post,
          status: :archived
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      expand_replies(view, first_post.id)

      assert has_element?(view, "#post_reply_#{reply.id}")
    end

    test "collab space has auto accept false",
         %{conn: conn, user: user, section: section, page_revision_cs: page_revision_cs} do
      collab_space_config = build(:collab_space_config, status: :enabled, auto_accept: false)
      message = "Testing Post"

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug
          }
        )

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{message: message}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      created_post =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )
        |> Enum.find(&(&1.content.message == message))

      assert has_element?(
               view,
               "#post_#{created_post.id}_actions .badge-info",
               "Pending approval"
             )

      view
      |> element("form#reply_form_#{created_post.id}")
      |> render_submit(%{"post" => %{content: %{message: "Testing reply"}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      reply =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )
        |> Enum.find(&(&1.parent_post_id == created_post.id))

      expand_replies(view, created_post.id)

      assert has_element?(
               view,
               "#post_#{reply.id}_actions .badge-info",
               "Pending approval"
             )
    end

    test "collab space is no threaded",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      collab_space_config = build(:collab_space_config, status: :enabled, threaded: false)

      reply =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          thread_root: first_post,
          parent_post: first_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "h3", "Discussion")
      assert has_element?(view, ".post-index", "#2")
      assert has_element?(view, ".post-content", "#{first_post.content.message}")
      assert has_element?(view, ".post-content", "#{reply.content.message}")

      refute has_element?(
               view,
               "button[phx-click=\"set_selected\"][phx-value-id=\"#{first_post.id}\"]"
             )

      refute has_element?(view, "#post_#{reply.id}_replies")
    end

    test "collab space does not show full history",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs
         } do
      message = "Testing post"

      collab_space_config =
        build(:collab_space_config, status: :enabled, show_full_history: false)

      content = build(:post_content, message: "New post")

      post =
        insert(:post,
          user: user,
          section: section,
          resource: page_resource_cs,
          inserted_at: yesterday(),
          updated_at: yesterday(),
          content: content
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "h3", "Discussion")
      refute has_element?(view, ".post-content", "#{post.content.message}")

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{message: message}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      created_post =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          page_revision_cs.resource_id,
          user.id
        )
        |> Enum.find(&(&1.content.message == message))

      assert has_element?(view, ".post-content", "#{created_post.content.message}")
    end

    test "collab space does not allow anonymous posting when that config is set to false",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs
         } do
      collab_space_config =
        build(:collab_space_config, status: :enabled, anonymous_posting: false)

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "button", "Create Post")
      refute has_element?(view, "button", "Post anonymously")
    end

    test "collab space allows anonymous posting when that config is set to true",
         %{
           conn: conn,
           user: user,
           section: section,
           page_revision_cs: page_revision_cs
         } do
      collab_space_config = build(:collab_space_config, status: :enabled, anonymous_posting: true)

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => user.id,
            "collab_space_config" => collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_student" => true
          }
        )

      assert has_element?(view, "button", "Create Post")
      assert has_element?(view, "button", "Post anonymously")
    end
  end

  describe "instructor - collab space view" do
    setup [:lms_instructor_conn, :create_project_and_section]

    test "creating a post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs
         } do
      message = "Testing post"

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      view
      |> element("#new_post_form")
      |> render_submit(%{"post" => %{content: %{message: message}}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully created"

      assert_receive {:post_created, %PostSchema{}}

      posts =
        Collaboration.list_posts_for_instructor_in_page_section(
          section.id,
          page_revision_cs.resource_id
        )

      assert length(posts) == 3

      assert has_element?(view, ".post-index", "#3")
      assert has_element?(view, ".post-content", "#{message}")
    end

    test "deleting a post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      %PostSchema{id: parent_post_id} =
        parent_post =
        insert(:post, user: instructor, section: section, resource: page_resource_cs)

      reply =
        insert(:post,
          user: instructor,
          section: section,
          resource: page_resource_cs,
          parent_post: parent_post,
          thread_root: parent_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{parent_post_id}\"]"
             )

      expand_replies(view, parent_post_id)

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{reply.id}\"]"
             )

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{first_post.id}\"]"
             )

      display_delete_modal(view, parent_post_id)
      confirm_delete(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post/s successfully deleted"

      assert_receive {:post_deleted, ^parent_post_id}

      posts =
        Collaboration.list_posts_for_instructor_in_page_section(
          section.id,
          page_revision_cs.resource_id
        )

      assert length(posts) == 2

      refute has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{parent_post_id}\"]"
             )

      refute has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{reply.id}\"]"
             )

      assert has_element?(
               view,
               "button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{first_post.id}\"]"
             )
    end

    test "accept submitted post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs,
           second_post: second_post
         } do
      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      assert has_element?(
               view,
               "#post_#{second_post.id}_actions .badge-info",
               "Pending approval"
             )

      display_accept_modal(view, second_post.id)
      confirm_accept(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      refute has_element?(
               view,
               "#post_#{second_post.id}_actions .badge-info",
               "Pending approval"
             )
    end

    test "reject submitted post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post,
           second_post: second_post
         } do
      post =
        insert(:post,
          user: instructor,
          section: section,
          resource: page_resource_cs,
          parent_post: second_post,
          thread_root: second_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      assert has_element?(
               view,
               "#post_#{second_post.id}_actions .badge-info",
               "Pending approval"
             )

      expand_replies(view, second_post.id)

      assert has_element?(view, "#post_reply_#{post.id}")
      assert has_element?(view, "#post_#{first_post.id}")

      display_reject_modal(view, second_post.id)
      confirm_reject(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post/s successfully deleted"

      posts =
        Collaboration.list_posts_for_instructor_in_page_section(
          section.id,
          page_revision_cs.resource_id
        )

      assert length(posts) == 1

      refute has_element?(view, "#post_#{second_post.id}")
      refute has_element?(view, "#post_reply#{post.id}")
      assert has_element?(view, "#post_#{first_post.id}")
    end

    test "archive post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs,
           first_post: first_post
         } do
      reply =
        insert(:post,
          user: instructor,
          section: section,
          resource: page_resource_cs,
          parent_post: first_post,
          thread_root: first_post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      expand_replies(view, first_post.id)

      refute has_element?(view, "#post_#{first_post.id}.readonly")
      refute has_element?(view, "#post_reply_#{reply.id}.readonly")

      display_archive_modal(view, reply.id)
      confirm_archive(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      refute has_element?(view, "#post_#{first_post.id}.readonly")
      assert has_element?(view, "#post_reply_#{reply.id}.readonly")

      display_archive_modal(view, first_post.id)
      confirm_archive(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      assert has_element?(view, "#post_#{first_post.id}.readonly")
    end

    test "unarchive post",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           page_revision_cs: page_revision_cs,
           page_resource_cs: page_resource_cs
         } do
      post =
        insert(:post,
          status: :archived,
          user: instructor,
          section: section,
          resource: page_resource_cs
        )

      reply =
        insert(:post,
          status: :archived,
          user: instructor,
          section: section,
          resource: page_resource_cs,
          parent_post: post,
          thread_root: post
        )

      {:ok, view, _html} =
        live_isolated(
          conn,
          CollabSpaceView,
          session: %{
            "current_user_id" => instructor.id,
            "collab_space_config" => page_revision_cs.collab_space_config,
            "section_slug" => section.slug,
            "page_slug" => page_revision_cs.slug,
            "is_instructor" => true
          }
        )

      expand_replies(view, post.id)

      assert has_element?(view, "#post_#{post.id}.readonly")
      assert has_element?(view, "#post_reply_#{reply.id}.readonly")

      display_unarchive_modal(view, reply.id)
      confirm_unarchive(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      assert has_element?(view, "#post_#{post.id}.readonly")
      refute has_element?(view, "#post_reply_#{reply.id}.readonly")

      display_unarchive_modal(view, post.id)
      confirm_unarchive(view)

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Post successfully edited"

      refute has_element?(view, "#post_#{post.id}.readonly")
    end
  end

  defp expand_replies(view, post_id) do
    view
    |> element("button[phx-click=\"set_selected\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp display_delete_modal(view, post_id) do
    view
    |> element("button[phx-click=\"display_delete_modal\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp confirm_delete(view) do
    view
    |> element("button[phx-click=\"delete_posts\"")
    |> render_click()
  end

  defp display_accept_modal(view, post_id) do
    view
    |> element("button[phx-click=\"display_accept_modal\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp confirm_accept(view) do
    view
    |> element("button[phx-click=\"accept_post\"")
    |> render_click()
  end

  defp display_reject_modal(view, post_id) do
    view
    |> element("button[phx-click=\"display_reject_modal\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp confirm_reject(view) do
    view
    |> element("button[phx-click=\"reject_post\"")
    |> render_click()
  end

  defp display_archive_modal(view, post_id) do
    view
    |> element("button[phx-click=\"display_archive_modal\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp confirm_archive(view) do
    view
    |> element("button[phx-click=\"archive_post\"")
    |> render_click()
  end

  defp display_unarchive_modal(view, post_id) do
    view
    |> element("button[phx-click=\"display_unarchive_modal\"][phx-value-id=\"#{post_id}\"]")
    |> render_click()
  end

  defp confirm_unarchive(view) do
    view
    |> element("button[phx-click=\"unarchive_post\"")
    |> render_click()
  end
end
