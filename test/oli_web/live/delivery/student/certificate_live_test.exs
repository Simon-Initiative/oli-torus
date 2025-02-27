defmodule OliWeb.Delivery.Student.CertificateLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "does not see a certificate if the provided guid does not exist", %{
      conn: conn,
      section: section
    } do
      guid = "non_existent_guid"
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/certificate/#{guid}")

      assert has_element?(
               view,
               "h3",
               "The requested certificate does not exist or belongs to another student"
             )
    end

    test "does not see a certificate if the provided guid belongs to another student", %{
      conn: conn,
      section: section,
      certificate: certificate
    } do
      granted_certificate_from_another_user =
        insert(:granted_certificate, certificate: certificate)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/certificate/#{granted_certificate_from_another_user.guid}"
        )

      assert has_element?(
               view,
               "h3",
               "The requested certificate does not exist or belongs to another student"
             )
    end

    test "sees a message if the certificate is being created", %{
      conn: conn,
      certificate: certificate,
      user: student
    } do
      granted_certificate =
        insert(:granted_certificate, %{
          certificate: certificate,
          user: student,
          url: nil
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{certificate.section.slug}/certificate/#{granted_certificate.guid}"
        )

      assert has_element?(
               view,
               "h3",
               "The requested certificate is being created. Please revisit the page in some minutes"
             )
    end

    test "sees the certificate if the user_id matches its own id", %{
      conn: conn,
      certificate: certificate,
      user: student
    } do
      granted_certificate =
        insert(:granted_certificate, %{
          certificate: certificate,
          user: student,
          url: "some_valid_pdf_url",
          guid: "some_guid"
        })

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{certificate.section.slug}/certificate/#{granted_certificate.guid}"
        )

      assert has_element?(view, "embed[src='some_valid_pdf_url']")
      assert render(view) =~ "some_guid"
    end

    test "can navigate back to the home page", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/certificate/some_guid")

      element(view, "a[href='/sections/#{section.slug}']")
      |> render_click()

      assert_redirected(view, ~p"/sections/#{section.slug}")
    end
  end

  defp create_elixir_project(ctx) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Start here"
      )

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_1_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions = [page_1_revision, container_revision]

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
        title: "The best course ever!"
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll user to the section
    Sections.enroll(ctx.user.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.mark_section_visited_for_student(section, ctx.user)

    certificate = insert(:certificate, section: section)

    %{section: section, certificate: certificate}
  end
end
