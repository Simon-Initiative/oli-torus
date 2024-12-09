defmodule OliWeb.ManageSourceMaterialsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Oli.Publishing
  alias Oli.Publishing.Publications.PublicationDiff
  alias OliWeb.Common.Utils

  defp live_view_source_materials(section_slug),
    do:
      Routes.source_materials_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.ManageSourceMaterials,
        section_slug
      )

  defp create_project_and_section(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision A"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_resource.id],
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

    # -------------------- Create another project with resource -------------------- #

    %{publication: another_publication, project: _project, unit_one_revision: _unit_one_revision} =
      base_project_with_curriculum(author)

    # ------------------------------------------------------------------------------ #

    product = insert(:section, type: :blueprint, base_project: project)

    section =
      insert(:section,
        base_project: project,
        type: :enrollable,
        open_and_free: true,
        registration_open: true,
        blueprint: product
      )

    {:ok, _sr} = Sections.create_section_resources(section, publication)
    {:ok, _sr} = Sections.create_section_resources(section, another_publication)

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      section: section,
      author: author
    ]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project_and_section]

    test "redirects to enroll page when accessing the manage source materials view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_source_materials(section.slug))
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn, :create_project_and_section]

    test "returns forbidden when accessing the manage source materials view", %{
      conn: conn,
      user: user,
      section: section
    } do
      enroll_user_to_section(user, section, :context_learner)

      assert conn
             |> get(live_view_source_materials(section.slug))
             |> html_response(302) =~
               "You are being <a href=\"/unauthorized\">redirected</a>"
    end
  end

  describe "user can access when is logged in as system admin" do
    setup [:admin_conn, :create_project_and_section]

    test "returns the manage source materials view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_source_materials(section.slug))

      assert html_response(conn, 200)
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:instructor_conn, :create_project_and_section]

    test "returns the manage source materials view", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      conn = get(conn, live_view_source_materials(section.slug))

      assert html_response(conn, 200)
    end
  end

  describe "shows the information of a section" do
    setup [:instructor_conn, :create_project_and_section]

    test "base project information is rendered", %{
      conn: conn,
      instructor: instructor,
      section: section,
      publication: publication
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      assert has_element?(view, "h6", "Base Project Info")
      assert has_element?(view, "h5", "#{section.base_project.title}")
      assert has_element?(view, "p", "#{section.base_project.description}")

      assert has_element?(
               view,
               ".badge-info",
               Utils.render_version(publication.edition, publication.major, publication.minor)
             )
    end

    test "product information is rendered", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      assert has_element?(view, "h6", "Product Info")
      assert has_element?(view, "h5", "#{section.blueprint.title}")
      assert has_element?(view, "p", "#{section.blueprint.description}")
    end

    test "remixed project information is rendered", %{
      conn: conn,
      instructor: instructor,
      section: section,
      project: project
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      [remixed_projects | _] = Sections.get_remixed_projects(section.id, project.id)
      %{publication: publication} = remixed_projects

      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      assert has_element?(view, "h6", "Remixed Projects Info")
      assert has_element?(view, "h5", "#{remixed_projects.title}")
      assert has_element?(view, "p", "#{remixed_projects.description}")

      assert has_element?(
               view,
               ".badge-info",
               Utils.render_version(publication.edition, publication.major, publication.minor)
             )
    end

    test "shows when there is a new publication to update", %{
      conn: conn,
      instructor: instructor,
      section: section,
      project: project
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      new_publication = insert(:publication, %{project: project})
      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      assert has_element?(view, "div", "An update is available for this section")

      assert has_element?(
               view,
               ".badge-success",
               Utils.render_version(
                 new_publication.edition,
                 new_publication.major,
                 new_publication.minor
               )
             )

      assert has_element?(
               view,
               "button[phx-click=\"show_apply_update_modal\"][phx-value-project-id=\"#{project.id}\"][phx-value-publication-id=\"#{new_publication.id}\"]",
               "View Update"
             )
    end
  end

  describe "shows only base project information of a section" do
    setup [:instructor_conn, :section_with_assessment]

    test "Only base project information is rendered", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)
      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      assert has_element?(view, "h6", "Base Project Info")
      assert has_element?(view, "h5", "#{section.base_project.title}")
      refute has_element?(view, "h6", "Product Info")
      refute has_element?(view, "h6", "Remixed Projects Info")
    end
  end

  describe "update publication" do
    setup [:instructor_conn, :create_project_and_section]

    test "update the publication of a section", %{
      conn: conn,
      instructor: instructor,
      section: section,
      project: project,
      publication: publication
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      new_publication =
        insert(:publication, %{project: project, description: "Example description", major: 2})

      %PublicationDiff{changes: changes} =
        Publishing.diff_publications(publication, new_publication)

      {:ok, view, _html} = live(conn, live_view_source_materials(section.slug))

      view
      |> element(
        "button[phx-click=\"show_apply_update_modal\"][phx-value-project-id=\"#{project.id}\"][phx-value-publication-id=\"#{new_publication.id}\"]"
      )
      |> render_click()

      assert has_element?(view, "h5", "Apply Update - #{project.title}")
      assert has_element?(view, "p", new_publication.description)

      for {status, %{revision: revision}} <- Map.values(changes) do
        assert has_element?(view, "span", revision.title)
        assert has_element?(view, ".badge-#{Atom.to_string(status)}")
      end

      view
      |> element("button[phx-click=\"apply_update\"]")
      |> render_click(%{section: section, publication: new_publication})

      refute has_element?(
               view,
               ".badge-success",
               Utils.render_version(publication.edition, publication.major, publication.minor)
             )

      refute has_element?(
               view,
               "button[phx-click=\"show_apply_update_modal\"][phx-value-project-id=\"#{project.id}\"][phx-value-publication-id=\"#{new_publication.id}\"]",
               "View Update"
             )
    end
  end
end
