defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLiveTest do
  use OliWeb.ConnCase

  import Ecto.Query
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections.Blueprint

  # Testing for the edit form is located in OliWeb.Sections.EditLiveTest

  defp live_view_route(project_slug, product_slug, params),
    do: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}/?#{params}"

  describe "user cannot access when is not logged in" do
    setup attrs do
      {:ok,
       attrs
       |> create_project()
       |> publish_project()
       |> create_product()}
    end

    test "redirects to new session when accessing product details view", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug, product.slug, %{}))

      assert redirect_path == "/authors/log_in"
      assert error_msg == "You must log in to access this page."
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup attrs do
      {:ok,
       attrs
       |> author_conn()
       |> response_to_map()
       |> add_new_author()
       |> create_project()
       |> publish_project()
       |> create_product()}
    end

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

  describe "product details page" do
    setup attrs do
      {:ok,
       attrs
       |> author_conn()
       |> response_to_map()
       |> create_project()
       |> publish_project()
       |> create_product()}
    end

    test "renders header", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      assert live
             |> element("#header_id")
             |> render() =~
               "Template Overview"
    end

    test "renders template usage action link", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      assert has_element?(
               live,
               "a[href='/workspaces/course_author/#{project.slug}/products/#{product.slug}/usage']",
               "View Usage"
             )
    end

    test "prepares template preview, creates an enrollment, and pushes a launch event", ctx do
      %{conn: conn, author: author, project: project, product: product} = ctx
      user = insert(:user, author: author, email: author.email)
      conn = conn |> log_in_user(user) |> log_in_author(author)

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))
      preview_url = "/sections/#{product.slug}"

      render_click(element(live, "button[phx-click='template_preview']"))

      assert_push_event(live, "template-preview-open", %{url: ^preview_url})

      enrollment =
        Oli.Delivery.Sections.get_enrollment(product.slug, user.id, filter_by_status: false)
        |> Oli.Repo.preload(:context_roles)

      assert enrollment.status == :enrolled

      assert Enum.any?(
               enrollment.context_roles,
               &(&1.id == Lti_1p3.Roles.ContextRoles.get_role(:context_learner).id)
             )

      assert has_element?(live, "a[href='/sections/#{product.slug}']", "Open Preview")
    end

    test "reuses the existing enrollment when preview is launched again", ctx do
      %{conn: conn, author: author, project: project, product: product} = ctx
      user = insert(:user, author: author, email: author.email)
      conn = conn |> log_in_user(user) |> log_in_author(author)

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))
      preview_url = "/sections/#{product.slug}"

      render_click(element(live, "button[phx-click='template_preview']"))
      assert_push_event(live, "template-preview-open", %{url: ^preview_url})

      render_click(element(live, "button[phx-click='template_preview']"))
      assert_push_event(live, "template-preview-open", %{url: ^preview_url})

      count =
        Oli.Repo.aggregate(
          from(e in Oli.Delivery.Sections.Enrollment,
            where: e.user_id == ^user.id and e.section_id == ^product.id
          ),
          :count,
          :id
        )

      assert count == 1
    end

    test "shows an error when the author has no linked learner account", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      render_click(element(live, "button[phx-click='template_preview']"))

      assert render(live) =~ "Preview requires a linked learner account for the current author"
      refute has_element?(live, "a[href='/sections/#{product.slug}']", "Open Preview")
    end
  end

  ##### HELPER FUNCTIONS #####
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Resources.ResourceType

  defp response_to_map({:ok, list}) do
    Enum.into(list, %{})
  end

  defp create_product(ctx) do
    {:ok, product} = Blueprint.create_blueprint(ctx.project.slug, "Some Product", nil)

    Map.merge(ctx, %{product: product})
  end

  defp publish_project(ctx) do
    Publishing.publish_project(ctx.project, "Datashop test", ctx.author.id)
    ctx
  end

  defp add_new_author(ctx) do
    author = insert(:author)
    Map.merge(Enum.into(ctx, %{}), %{author: author})
  end

  defp create_project(ctx) do
    author = ctx[:author] || insert(:author)
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

    Map.merge(ctx, %{project: project, publication: publication, author: author})
  end
end
