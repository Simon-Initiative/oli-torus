defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections.Blueprint

  # Testing for the edit form is located in OliWeb.Sections.EditLiveTest

  defp live_view_route(project_slug, product_slug, params),
    do: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}/?#{params}"

  describe "user cannot access when is not logged in" do
    setup [:create_project, :publish_project, :create_product]

    test "redirects to new session when accessing product details view", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug, product.slug, %{}))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You must be logged in to access that project"

      {:ok, _view, html} = live(conn, redirect_path)

      assert html =~
               "<span class=\"text-white font-normal font-[&#39;Open Sans&#39;] leading-10\">\n            Welcome to\n          </span><span class=\"text-white font-bold font-[&#39;Open Sans&#39;] leading-10\">\n            OLI Torus\n          </span>"
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn, :create_project, :publish_project, :create_product]

    test "redirects to projects view when accessing the bibliography view", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug, product.slug, %{}))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You don't have access to that project"

      {:ok, view, _html} = live(conn, redirect_path)

      assert render(element(view, "#button-new-project")) =~ "New Project"
    end
  end

  ##### HELPER FUNCTIONS #####
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Resources.ResourceType

  defp create_product(ctx) do
    {:ok, product} = Blueprint.create_blueprint(ctx.project.slug, "Some Product", nil)

    {:ok, %{product: product}}
  end

  defp publish_project(ctx) do
    Publishing.publish_project(ctx.project, "Datashop test", ctx.author.id)
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
