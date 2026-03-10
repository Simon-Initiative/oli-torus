defmodule OliWeb.Products.UsageViewTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Accounts.SystemRole
  alias Oli.Publishing
  alias Oli.Resources.ResourceType

  defp usage_route(product_slug, params \\ %{}),
    do: ~p"/authoring/products/#{product_slug}/usage?#{params}"

  describe "usage page access" do
    setup attrs do
      {:ok,
       attrs
       |> create_project()
       |> publish_project()
       |> create_product()}
    end

    test "redirects to login when unauthenticated", %{conn: conn, product: product} do
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, usage_route(product.slug))

      assert redirect_path == "/authors/log_in"
      assert error_msg == "You must log in to access this page."
    end
  end

  describe "usage page behavior" do
    setup attrs do
      {:ok,
       attrs
       |> author_conn()
       |> response_to_map()
       |> create_project()
       |> publish_project()
       |> create_product()}
    end

    test "renders template usage title and download link", %{
      conn: conn,
      project: project,
      product: product
    } do
      insert(:section,
        type: :enrollable,
        title: "Section From Template",
        base_project: project,
        blueprint_id: product.id
      )

      {:ok, view, _html} = live(conn, usage_route(product.slug))

      assert has_element?(view, "h2", "#{product.title} Usage")
      assert has_element?(view, "a", "Download CSV")
      assert has_element?(view, "th", "Project Version")
      refute has_element?(view, "th", "Tags")
    end

    test "applies active_today filter", %{conn: conn, project: project, product: product} do
      active_section =
        insert(:section,
          type: :enrollable,
          title: "Active Usage Section",
          start_date: DateTime.utc_now() |> DateTime.add(-3600, :second),
          end_date: DateTime.utc_now() |> DateTime.add(3600, :second),
          base_project: project,
          blueprint_id: product.id
        )

      inactive_section =
        insert(:section,
          type: :enrollable,
          title: "Inactive Usage Section",
          start_date: DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second),
          end_date: DateTime.utc_now() |> DateTime.add(-2 * 86_400, :second),
          base_project: project,
          blueprint_id: product.id
        )

      {:ok, view, _html} = live(conn, usage_route(product.slug))

      assert has_element?(view, "td", active_section.title)
      assert has_element?(view, "td", inactive_section.title)

      view
      |> element("input[phx-click='active_today']")
      |> render_click()

      assert has_element?(view, "td", active_section.title)
      refute has_element?(view, "td", inactive_section.title)
    end

    test "shows tags column to admins", %{project: project, product: product} do
      admin = insert(:author, %{system_role_id: SystemRole.role_id().content_admin})

      insert(:section,
        type: :enrollable,
        title: "Admin Visible Tags Section",
        base_project: project,
        blueprint_id: product.id
      )

      conn =
        build_conn()
        |> log_in_author(admin)

      {:ok, view, _html} = live(conn, usage_route(product.slug))

      assert has_element?(view, "th", "Tags")
    end
  end

  defp response_to_map({:ok, list}), do: Enum.into(list, %{})

  defp create_product(ctx) do
    {:ok, product} = Blueprint.create_blueprint(ctx.project.slug, "Some Product", nil)

    Map.merge(ctx, %{product: product})
  end

  defp publish_project(ctx) do
    Publishing.publish_project(ctx.project, "Datashop test", ctx.author.id)
    ctx
  end

  defp create_project(ctx) do
    author = ctx[:author] || insert(:author)
    project = insert(:project, authors: [author])
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.id_for_container(),
        content: %{},
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    Map.merge(ctx, %{project: project, publication: publication, author: author})
  end
end
