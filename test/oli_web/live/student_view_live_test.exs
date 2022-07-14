defmodule OliWeb.StudentViewLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections

  defp live_view_student_view_route(section_slug, user_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Progress.StudentView,
      section_slug,
      user_id
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:setup_section]

    test "redirects to section enroll page when accessing the student view", %{
      conn: conn,
      section: section,
      student: student
    } do
      redirect_path = "/sections/#{section.slug}/enroll"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_student_view_route(section.slug, student.id))
    end
  end

  describe "student cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :setup_section]

    test "redirects to enroll page when accessing the student view", %{
      conn: conn,
      section: section,
      student: student
    } do
      conn = get(conn, live_view_student_view_route(section.slug, student.id))

      redirect_path = "/sections/#{section.slug}/enroll"

      assert conn
             |> get(live_view_student_view_route(section.slug, student.id))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "student view" do
    setup [:admin_conn, :setup_section]

    scores_expected_format = %{
      1.334 => 1.33,
      1.336 => 1.34,
      4.889 => 4.89,
      7.33333 => 7.33,
      9.10 => 9.10,
      5 => 5.0,
      0.0 => 0.0,
      0 => 0.0,
    }

    for {score, expected_score} <- scores_expected_format do
      @score score
      @expected_score expected_score
      @out_of 10.0

      test "loads student view data correctly with score #{score}", %{
        conn: conn,
        section: section,
        page_revision: page_revision,
        student: student
      } do
        resource_access =
          insert(:resource_access,
            user: student,
            resource: page_revision.resource,
            section: section,
            score: @score,
            out_of: @out_of
          )

        insert(:resource_attempt, resource_access: resource_access)

        {:ok, view, html} = live(conn, live_view_student_view_route(section.slug, student.id))

        assert html =~ "Progress Details for #{student.family_name}, #{student.given_name}"

        assert view
          |> element("tr[id=\"0\" phx-value-id=\"0\"]")
          |> render =~ "#{@expected_score} / #{@out_of}"

        assert view
        |> element("tr[id=\"0\" phx-value-id=\"0\"]")
        |> render =~ "<a href=\"/sections/#{section.slug}/progress/#{student.id}/#{page_revision.resource.id}\">#{page_revision.title}</a>"
      end
    end
  end

  def setup_section(_context) do
    project = insert(:project)

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Progress test revision",
        graded: true
      )

    # Associate nested graded page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_revision.resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{project: project, root_resource_id: container_resource.id})

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    # Publish nested page resource
    insert(:published_resource, %{
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision
    })

    section = insert(:section, base_project: project, context_id: UUID.uuid4(), open_and_free: true, registration_open: true)

    student = insert(:user)

    {:ok, section} = Sections.create_section_resources(section, publication)

    {:ok, section: section, page_revision: page_revision, student: student}
  end
end
