defmodule OliWeb.CollabSpaceConfigLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Resources.ResourceType
  alias OliWeb.CollaborationLive.CollabSpaceConfigView

  defp create_project_and_section(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []}
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
        collab_space_config: collab_space_config
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

    section = insert(:section, base_project: project)
    {:ok, _sr} = Sections.create_section_resources(section, publication)

    [
      project: project,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      section: section,
      author: author,
      page_resource_cs: page_resource_cs
    ]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project_and_section]

    test "redirects to new session when accessing the author edit page view", %{
      conn: conn,
      project: project,
      page_revision: page_revision
    } do
      assert conn
            |> get(Routes.resource_path(conn, :edit, project.slug, page_revision.slug))
            |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fresource%2F#{page_revision.slug}\">redirected</a>"
    end

    test "returns forbidden when accessing the instructor preview view", %{
      conn: conn,
      section: section,
      page_revision: page_revision
    } do
      assert conn
            |> get(
              Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision.slug)
            )
            |> html_response(403)
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
            |> get(Routes.resource_path(conn, :edit, project.slug, page_revision.slug))
            |> html_response(302) =~
              "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fresource%2F#{page_revision.slug}\">redirected</a>"
    end

    test "redirects to page when accessing the instructor preview view", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      enroll_user_to_section(user, section, :context_learner)

      assert conn
            |> get(
              Routes.page_delivery_path(conn, :page_preview, section.slug, page_revision.slug)
            )
            |> html_response(302) =~
              "You are being <a href=\"/sections/#{section.slug}/page/#{page_revision.slug}"
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

    test "redirects to new session when accessing the author edit page view", %{
      conn: conn,
      project: project,
      page_revision: page_revision
    } do
      assert conn
            |> get(Routes.resource_path(conn, :edit, project.slug, page_revision.slug))
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
        |> get(Routes.resource_path(conn, :edit, project.slug, page_revision.slug))

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

      assert view |> element("#delivery_setting_collab_space_config_threaded") |> render() =~
              "checked"

      assert view |> element("#delivery_setting_collab_space_config_auto_accept") |> render() =~
              "checked"

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

      refute view |> element("#delivery_setting_collab_space_config_threaded") |> render() =~
              "checked"

      refute view |> element("#delivery_setting_collab_space_config_auto_accept") |> render() =~
              "checked"

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
end
