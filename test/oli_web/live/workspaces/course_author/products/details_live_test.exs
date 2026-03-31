defmodule OliWeb.Workspaces.CourseAuthor.Products.DetailsLiveTest do
  use OliWeb.ConnCase

  import Ecto.Query
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

    test "renders the cover image section beneath paywall settings with shared preview gallery",
         ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, product} =
        Oli.Delivery.Sections.update_section(product, %{
          cover_image: "https://example.com/template-cover.png"
        })

      {:ok, live, html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      assert has_element?(live, "h4", "Cover Image")

      assert has_element?(
               live,
               "div",
               "Manage the cover image for this template. Max file size is 5 MB."
             )

      assert has_element?(
               live,
               "#selected-image-preview #current-product-img[src='https://example.com/template-cover.png']"
             )

      assert render(live) =~
               "background-image: url(&#39;https://example.com/template-cover.png&#39;);"

      assert has_element?(live, "#selected-image-preview[data-preview-context='cover_image']")
      assert has_element?(live, "#image-preview-thumbnails")
      assert has_element?(live, "#image-preview-thumbnail-my-course")
      assert has_element?(live, "#image-preview-thumbnail-course-picker")
      assert has_element?(live, "#image-preview-thumbnail-student-welcome")
      assert has_element?(live, "#image-preview-thumbnail-my-course [data-preview-mode='true']")

      assert has_element?(
               live,
               "#image-preview-thumbnail-course-picker [data-preview-mode='true']"
             )

      assert has_element?(live, "#image-preview-thumbnail-student-welcome", "Welcome to")

      assert has_element?(
               live,
               ".image-preview-thumbnail .hover\\:shadow-\\[0_12px_32px_rgba\\(15\\,13\\,15\\,0\\.24\\)\\]"
             )

      {paywall_index, _} = :binary.match(html, "Paywall Settings")
      {cover_image_index, _} = :binary.match(html, "Cover Image")
      {content_index, _} = :binary.match(html, "Content")

      assert paywall_index < cover_image_index
      assert cover_image_index < content_index
    end

    test "renders no preview gallery when no image is set", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      refute has_element?(live, "#img-preview-gallery")
      refute has_element?(live, "#current-product-img")
    end

    test "opens the image preview modal and cycles through the three preview labels", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, product} =
        Oli.Delivery.Sections.update_section(product, %{
          cover_image: "https://example.com/template-cover.png"
        })

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      render_click(element(live, "#image-preview-thumbnail-student-welcome"))

      assert has_element?(live, "#image-preview-modal.block")
      assert has_element?(live, "#image-preview-modal", "Student Course Introduction")

      assert has_element?(
               live,
               "#image-preview-modal button[phx-click='show_previous_image_preview'][disabled]"
             )

      render_click(
        element(live, "#image-preview-modal button[phx-click='show_next_image_preview']")
      )

      assert has_element?(live, "#image-preview-modal", "My Courses")

      render_click(
        element(live, "#image-preview-modal button[phx-click='show_next_image_preview']")
      )

      assert has_element?(live, "#image-preview-modal", "Course Picker")

      assert has_element?(
               live,
               "#image-preview-modal button[phx-click='show_next_image_preview'][disabled]"
             )

      render_click(
        element(
          live,
          "#image-preview-modal button[aria-label='close']"
        )
      )

      refute has_element?(live, "#image-preview-modal.block")
    end

    test "places tags between description and welcome message title", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)
      {:ok, _} = Tags.associate_tag_with_section(product.id, tag.id, actor: admin)

      {:ok, _live, html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      {description_index, _} = :binary.match(html, "Description")
      {tags_index, _} = :binary.match(html, "Tags")
      {welcome_title_index, _} = :binary.match(html, "Welcome Message Title")

      assert description_index < tags_index
      assert tags_index < welcome_title_index
    end

    test "renders Duplicate as a button and Preview last in the actions list", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))
      html = render(live)

      assert has_element?(
               live,
               "a[href='/workspaces/course_author/#{project.slug}/products/#{product.slug}/usage']",
               "View Usage"
             )

      assert has_element?(
               live,
               "button[phx-click='request_duplicate'].btn.btn-secondary",
               "Duplicate"
             )

      assert has_element?(
               live,
               "button[phx-click='template_preview'].btn.btn-primary",
               "Preview Template"
             )

      assert html =~ "fa-solid fa-eye"

      assert elem(:binary.match(html, "Duplicate"), 0) <
               elem(:binary.match(html, "Preview Template"), 0)

      assert elem(:binary.match(html, "View Usage"), 0) <
               elem(:binary.match(html, "Preview Template"), 0)
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

    test "uses hidden instructor fallback when no current user is present", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))
      preview_url = "/authoring/products/#{product.slug}/preview_launch"

      render_click(element(live, "button[phx-click='template_preview']"))

      assert_push_event(live, "template-preview-open", %{url: ^preview_url})
      assert has_element?(live, "a[href='#{preview_url}']", "Open Preview")
    end

    test "keeps paywall fields disabled for non-admin workspace authors", ctx do
      %{conn: conn, project: project, product: product} = ctx

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      initial_html = live |> element("#paywall-settings-form") |> render()
      assert initial_html =~ ~r/name="section\[amount\]"[^>]*disabled=/

      updated_html =
        live
        |> element("#paywall-settings-form")
        |> render_change(%{"section" => %{"requires_payment" => "true"}})

      assert updated_html =~ ~r/name="section\[amount\]"[^>]*disabled=/
      assert updated_html =~ ~r/name="section\[payment_options\]"[^>]*disabled=/
      assert updated_html =~ ~r/name="section\[has_grace_period\]"[^>]*disabled=/
      refute updated_html =~ "Manage Discounts"
    end

    test "shows Manage Discounts for admin authors when requires payment is checked", ctx do
      %{project: project, product: product} = ctx

      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)
      conn = build_conn() |> log_in_author(admin)

      {:ok, live, _html} = live(conn, live_view_route(project.slug, product.slug, %{}))

      refute has_element?(
               live,
               "a[href='/authoring/products/#{product.slug}/discounts']",
               "Manage Discounts"
             )

      updated_html =
        live
        |> element("#paywall-settings-form")
        |> render_change(%{"section" => %{"requires_payment" => "true"}})

      assert updated_html =~ "Manage Discounts"
      assert updated_html =~ ~r/href="[^"]*\/discounts"/
    end

    test "renders only non-admin-safe details additions for workspace authors", ctx do
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

      refute has_element?(live, "label", "Communities")
      refute has_element?(live, "label", "Institutions")
      refute html =~ "Test Community"
      refute html =~ "Visibility University"
      refute has_element?(live, "a[href='/authoring/communities/#{community.id}']")
      refute has_element?(live, "a[href='/admin/institutions/#{institution.id}']")
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
