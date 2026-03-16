defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Tags

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

    test "renders paywall settings after details with support text and controls", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      assert has_element?(live, "h4", "Paywall Settings")
      assert has_element?(live, "#tech_support_paywall_settings", "contact our support team.")
      assert html =~ "Requires payment"
      assert html =~ "Amount"
      assert html =~ "Payment options"
      assert html =~ "Has grace period"
      assert html =~ "Grace period days"
      refute html =~ "Payment Settings"
      refute html =~ "Settings related to required student fee and optional grace period"

      {details_index, _} = :binary.match(html, "Details")
      {paywall_index, _} = :binary.match(html, "Paywall Settings")
      {content_index, _} = :binary.match(html, "Content")

      assert details_index < paywall_index
      assert paywall_index < content_index
    end

    test "enables paywall fields when requires payment is checked", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      initial_html = live |> element("#paywall-settings-form") |> render()
      assert initial_html =~ ~r/name="section\[amount\]"[^>]*disabled=/

      updated_html =
        live
        |> element("#paywall-settings-form")
        |> render_change(%{"section" => %{"requires_payment" => "true"}})

      refute updated_html =~ ~r/name="section\[amount\]"[^>]*disabled=/
      refute updated_html =~ ~r/name="section\[has_grace_period\]"[^>]*disabled=/
    end

    test "renders details additions for workspace authors", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)
      {:ok, _} = Tags.associate_tag_with_section(product.id, tag.id, actor: admin)

      community = insert(:community, name: "Test Community")
      institution = insert(:institution, name: "Visibility University")

      insert(:community_product_visibility, community: community, section: product)

      insert(:project_institution_visibility,
        project_id: project.id,
        institution_id: institution.id
      )

      {:ok, live, html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      assert has_element?(live, "label", "Tags")
      assert html =~ "Biology"
      refute has_element?(live, "div[phx-hook='TagsComponent']")

      assert has_element?(live, "label", "Communities")

      assert has_element?(
               live,
               "a[href='/authoring/communities/#{community.id}']",
               "Test Community"
             )

      assert has_element?(live, "label", "Institutions")

      assert has_element?(
               live,
               "a[href='/admin/institutions/#{institution.id}']",
               "Visibility University"
             )
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
