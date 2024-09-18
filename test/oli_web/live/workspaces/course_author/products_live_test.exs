defmodule OliWeb.Workspace.CourseAuthor.ProductsLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections.Blueprint

  defp live_view_route(project_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/products?#{params}"

  describe "user cannot access when is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing the bibliography view", %{
      conn: conn,
      project: project
    } do
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You must be logged in to access that project"

      {:ok, _view, html} = live(conn, redirect_path)

      assert html =~
               "<span class=\"text-white font-normal font-[&#39;Open Sans&#39;] leading-10\">\n            Welcome to\n          </span><span class=\"text-white font-bold font-[&#39;Open Sans&#39;] leading-10\">\n            OLI Torus\n          </span>"
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn, :create_project]

    test "redirects to projects view when accessing the bibliography view", %{
      conn: conn,
      project: project
    } do
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You don't have access to that project"

      {:ok, view, _html} = live(conn, redirect_path)

      assert view
             |> element("#button-new-project")
             |> render() =~ "New Project"
    end
  end

  describe "products not published" do
    setup [:admin_conn, :create_project]

    test "cannot be created message", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element("#content")
             |> render() =~ "Products cannot be created until project is published."
    end
  end

  describe "products" do
    setup [:admin_conn, :create_project, :publish_project]

    test "toggle sidebar", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      path_with_expanded_sidebar_false =
        "/workspaces/course_author/#{project.slug}/products?sidebar_expanded=false"

      assert view
             |> element(~s{button[role="toggle sidebar"]})
             |> render() =~ path_with_expanded_sidebar_false

      path_with_expanded_sidebar_true =
        "/workspaces/course_author/#{project.slug}/products?sidebar_expanded=true"

      # Click to toggle sidebar
      view |> element(~s{button[role="toggle sidebar"]}) |> render_click()

      assert view
             |> element(~s{button[role="toggle sidebar"]})
             |> render() =~ path_with_expanded_sidebar_true
    end

    test "render message when no products exists", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element("#content")
             |> render() =~ "None exist"
    end

    test "create a product", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Submit form to create a product
      view
      |> form("form", create_product_form: %{"product_title" => "Some product"})
      |> render_submit()

      # Flash message
      assert view |> element("div[role='alert']") |> render() =~ "Product successfully created."

      # Total count message
      assert render(view) =~ "Showing all results (1 total)"

      # Table content
      product_title_col = render(element(view, "table tbody tr td:nth-of-type(1) div"))

      # Table content - Product title - text
      assert product_title_col =~ "Some product"

      # Table content - Product title - anchor
      assert product_title_col =~
               "/workspaces/course_author/#{project.slug}/products/some_product"

      # Table content - Status
      assert render(element(view, "table tbody tr td:nth-of-type(2) div")) =~ "active"
      assert render(element(view, "table tbody tr td:nth-of-type(3) div")) =~ "None"

      # Table content - Base project
      base_project_col = render(element(view, "table tbody tr td:nth-of-type(4) div"))

      # Table content - Base project - text
      assert base_project_col =~ "#{project.title}"

      # Table content - Base project - anchor
      assert base_project_col =~
               "/workspaces/course_author/#{project.slug}/overview"
    end

    test "trigger archived products checkbox", %{conn: conn, project: project} do
      product_title_1 = "Some product 1"
      product_title_2 = "Some product 2"
      {:ok, product_1} = Blueprint.create_blueprint(project.slug, product_title_1, nil)
      {:ok, _product_2} = Blueprint.create_blueprint(project.slug, product_title_2, nil)

      # Archive product 1
      Oli.Delivery.Sections.update_section!(product_1, %{status: :archived})

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Check archived products checkbox is not checked
      refute view |> element("input[type=\"checkbox\"]") |> render() =~ "checked=\"checked\""

      # Total count message
      assert render(view) =~ "Showing all results (1 total)"

      # Check archived products are not displayed
      rows =
        view
        |> element("table tbody")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("tr")

      refute Floki.text(rows) =~ "Some product 1"
      assert Floki.text(rows) =~ "Some product 2"

      assert Enum.count(rows) == 1

      # Toggle archived products checkbox - It should be 2 products now
      view |> element("input[type='checkbox']") |> render_click()

      # Check archived products checkbox is checked
      assert view |> element("input[type=\"checkbox\"]") |> render() =~ "checked=\"checked\""

      # Total count message
      assert render(view) =~ "Showing all results (2 total)"

      # Check archived products are displayed
      rows =
        view
        |> element("table tbody")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("tr")

      assert Enum.count(rows) == 2

      assert Floki.text(rows) =~ "Some product 1"
      assert Floki.text(rows) =~ "Some product 2"
    end
  end

  ##### HELPER FUNCTIONS #####
  alias Oli.Resources.ResourceType

  defp publish_project(context) do
    Oli.Publishing.publish_project(context.project, "Datashop test", context.author.id)
    {:ok, %{}}
  end

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    # root container
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.id_for_container(),
        content: %{},
        slug: "root_container",
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})
    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    [project: project, publication: publication, author: author]
  end
end
