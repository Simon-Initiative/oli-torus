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

      assert redirect_path == "/authors/log_in"

      assert error_msg == "You must log in to access this page."
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
             |> render() =~ "Templates cannot be created until project is published."
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

      assert render(view) =~ "Course Section Templates"
      assert render(view) =~ "Building a course section template allows you to rearrange content"
      assert render(view) =~ "New Template"

      assert view
             |> element("#content")
             |> render() =~ "None exist"
    end

    test "create a product", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("#button-new-template")
      |> render_click()

      assert render(view) =~ "Create Template"
      assert render(view) =~ "This can be changed later"
      assert has_element?(view, "button[type='submit']", "Create")

      # Submit form to create a product
      view
      |> form("form[phx-submit='create']",
        create_product_form: %{"product_title" => "Some product"}
      )
      |> render_submit()

      flash =
        assert_redirected(
          view,
          "/workspaces/course_author/#{project.slug}/products/some_product"
        )

      assert flash["info"] == "Template successfully created."
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
      refute view |> element("input[type=\"checkbox\"]") |> render() =~ "checked=\"\""

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
      assert view |> element("input[type=\"checkbox\"]") |> render() =~ "checked=\"\""

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

    test "changing page size does not crash", %{conn: conn, project: project} do
      Enum.each(1..12, fn n ->
        {:ok, _} = Blueprint.create_blueprint(project.slug, "Some product #{n}", nil)
      end)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      # Ensure page size interaction is handled by the liveview without crashing
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "10"})

      assert has_element?(view, "table tbody tr")
      assert has_element?(view, "#footer_paging button[phx-click='paged_table_page_change']", "2")
    end

    test "search templates by name", %{conn: conn, project: project} do
      {:ok, _} = Blueprint.create_blueprint(project.slug, "Algebra Template", nil)
      {:ok, _} = Blueprint.create_blueprint(project.slug, "Biology Template", nil)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("form[phx-change='search_template']")
      |> render_change(%{"search_term" => "Algebra"})

      rows =
        view
        |> element("table tbody")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("tr")

      assert Enum.count(rows) == 1
      assert Floki.text(rows) =~ "Algebra Template"
      refute Floki.text(rows) =~ "Biology Template"
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
