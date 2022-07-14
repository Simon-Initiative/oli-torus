defmodule OliWeb.GradebookViewLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections

  defp live_view_gradebook_view_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Grades.GradebookView,
      section_slug
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:setup_section]

    test "redirects to enroll page when accessing the gradebook view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/sections/#{section.slug}/enroll"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_gradebook_view_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :setup_section]

    test "redirects to section enroll page when accessing the student view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_gradebook_view_route(section.slug))

      redirect_path = "/sections/#{section.slug}/enroll"

      assert conn
             |> get(live_view_gradebook_view_route(section.slug))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "gradebook view" do
    setup [:admin_conn, :setup_section]

    scores_expected_format = %{
      100.334 => 100.33,
      119.336 => 119.34,
      62.889 => 62.89,
      60.33333 => 60.33,
      90.10 => 90.10,
      120 => 120.0,
      0.0 => 0.0,
      0 => 0.0,
    }

    for {score, expected_score} <- scores_expected_format do
      @score score
      @expected_score expected_score
      @out_of 120.0

      test "loads gradebook view table data correctly with score: #{score}", %{
        conn: conn,
        section: section,
        page_revision: page_revision
      } do
        user = insert(:user)
        enroll_user_to_section(user, section, :context_learner)

        resource_access =
          insert(:resource_access,
            user: user,
            resource: page_revision.resource,
            section: section,
            score: @score,
            out_of: @out_of
          )

        insert(:resource_attempt, resource_access: resource_access)

        {:ok, view, _html} = live(conn, live_view_gradebook_view_route(section.slug))

        assert view
          |> element("tr[phx-value-id=\"#{user.id}\"] a[href=\"/sections/#{section.slug}/progress/#{user.id}/#{page_revision.resource.id}\"]")
          |> render =~ "#{@expected_score}/#{@out_of}"
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

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    {:ok, section: section, page_revision: page_revision}
  end
end
