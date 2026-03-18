defmodule OliWeb.Products.DetailsViewTest do
  use OliWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  alias OliWeb.Products.Details.Content
  alias Oli.Tags

  defp product_route(product_slug), do: ~p"/authoring/products/#{product_slug}"

  defp setup_admin_conn(_) do
    admin =
      insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)

    conn = log_in_author(build_conn(), admin)

    {:ok, conn: conn, admin: admin}
  end

  defp setup_author_conn(_) do
    author = insert(:author)
    conn = log_in_author(build_conn(), author)

    {:ok, conn: conn, author: author}
  end

  defp create_product(%{admin: admin}) do
    project = insert(:project, authors: [admin])
    product = insert(:section, base_project: project, type: :blueprint)

    {:ok, project: project, product: product}
  end

  defp create_product_for_author(%{author: _author}) do
    # Products are accessed via /authoring/products/:slug which requires admin role.
    # For author tests we still need a product to exist.
    admin =
      insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)

    project = insert(:project, authors: [admin])
    product = insert(:section, base_project: project, type: :blueprint)

    {:ok, project: project, product: product, admin: admin}
  end

  describe "product details page - tags for admin" do
    setup [:setup_admin_conn, :create_product]

    test "displays Tags section with editable TagsComponent", %{
      conn: conn,
      product: product,
      admin: admin
    } do
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      {:ok, _} = Tags.associate_tag_with_section(product.id, tag.id, actor: admin)

      {:ok, view, _html} = live(conn, product_route(product.slug))

      # Admin should see Tags label and TagsComponent
      assert has_element?(view, "label", "Tags")
      assert has_element?(view, "div[phx-hook='TagsComponent']")
    end

    test "displays TagsComponent for admin when product has no tags", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      # Admin should see Tags label and editable TagsComponent even with no tags
      assert has_element?(view, "label", "Tags")
      assert has_element?(view, "div[phx-hook='TagsComponent']")
    end

    test "displays tags when product has tags", %{
      conn: conn,
      product: product,
      admin: admin
    } do
      {:ok, tag1} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, tag2} = Tags.create_tag(%{name: "Advanced"})
      {:ok, _} = Tags.associate_tag_with_section(product.id, tag1.id, actor: admin)
      {:ok, _} = Tags.associate_tag_with_section(product.id, tag2.id, actor: admin)

      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "span[role='listitem']", "Chemistry")
      assert has_element?(view, "span[role='listitem']", "Advanced")
    end
  end

  describe "product details page - tags for non-admin authors" do
    setup [:setup_author_conn, :create_product_for_author]

    test "non-admin authors are redirected from product details page", %{
      conn: conn,
      product: product
    } do
      # Non-admin authors should be redirected to unauthorized page
      assert {:error, {:redirect, %{to: "/unauthorized"}}} =
               live(conn, product_route(product.slug))
    end
  end

  describe "product details page - communities" do
    setup [:setup_admin_conn, :create_product]

    test "displays Communities section with 'None' when no communities", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "label", "Communities")

      # Scope "None" to the Communities container to avoid matching other sections
      communities_html = view |> element("#communities-section") |> render()
      assert communities_html =~ "None"
    end

    test "displays community as a link when product has community", %{
      conn: conn,
      product: product
    } do
      community = insert(:community, name: "Test Community")
      insert(:community_product_visibility, community: community, section: product)

      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "label", "Communities")

      assert has_element?(
               view,
               "a[href='/authoring/communities/#{community.id}']",
               "Test Community"
             )
    end

    test "displays multiple communities as comma-separated links", %{
      conn: conn,
      product: product
    } do
      community1 = insert(:community, name: "Community Alpha")
      community2 = insert(:community, name: "Community Beta")
      insert(:community_product_visibility, community: community1, section: product)
      insert(:community_product_visibility, community: community2, section: product)

      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(
               view,
               "a[href='/authoring/communities/#{community1.id}']",
               "Community Alpha"
             )

      assert has_element?(
               view,
               "a[href='/authoring/communities/#{community2.id}']",
               "Community Beta"
             )
    end
  end

  describe "product details page - institutions with access" do
    setup [:setup_admin_conn, :create_product]

    test "displays Institutions section with 'None' when no institutions have access", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "label", "Institutions")

      # Scope "None" to the Institutions container to avoid matching other sections
      institutions_html = view |> element("#institutions-section") |> render()
      assert institutions_html =~ "None"
    end

    test "displays institution from base project's publishing visibility (Path A)", %{
      conn: conn,
      product: product,
      project: project
    } do
      institution = insert(:institution, name: "Visibility University")

      insert(:project_institution_visibility,
        project_id: project.id,
        institution_id: institution.id
      )

      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "label", "Institutions")

      assert has_element?(
               view,
               "a[href='/admin/institutions/#{institution.id}']",
               "Visibility University"
             )
    end

    test "displays institution from shared community membership (Path B)", %{
      conn: conn,
      product: product
    } do
      institution = insert(:institution, name: "Community University")
      community = insert(:community, name: "Shared Community")
      insert(:community_product_visibility, community: community, section: product)
      insert(:community_institution, community: community, institution: institution)

      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(
               view,
               "a[href='/admin/institutions/#{institution.id}']",
               "Community University"
             )
    end

    test "deduplicates institutions visible through both paths", %{
      conn: conn,
      product: product,
      project: project
    } do
      institution = insert(:institution, name: "Dual Access University")

      # Path A: publishing visibility
      insert(:project_institution_visibility,
        project_id: project.id,
        institution_id: institution.id
      )

      # Path B: community membership
      community = insert(:community, name: "Overlap Community")
      insert(:community_product_visibility, community: community, section: product)
      insert(:community_institution, community: community, institution: institution)

      {:ok, _view, html} = live(conn, product_route(product.slug))

      # Institution should appear exactly once
      assert length(Regex.scan(~r/Dual Access University/, html)) == 1
    end
  end

  describe "product details page - paywall settings section" do
    setup [:setup_admin_conn, :create_product]

    test "displays Paywall Settings section with support team link", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "h4", "Paywall Settings")
      assert has_element?(view, "p", "For information regarding paywall settings")
      assert has_element?(view, "#tech_support_paywall_settings", "contact our support team.")
    end

    test "paywall settings are no longer in the Details form", %{
      conn: conn,
      product: product
    } do
      {:ok, _view, html} = live(conn, product_route(product.slug))

      # Paywall fields should NOT be in the Details section form
      refute html =~ "Requires Payment"
      refute html =~ "Has Grace Period"
      refute html =~ "Grace period days"
    end
  end

  describe "product details page - overview sections" do
    setup [:setup_admin_conn, :create_product]

    test "displays all expected overview sections", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Paywall Settings")
      assert has_element?(view, "h4", "Content")
      assert has_element?(view, "h4", "Cover Image")
      assert has_element?(view, "h4", "Certificate Settings")
      assert has_element?(view, "h4", "Feature Flags")
      assert has_element?(view, "h4", "Actions")
    end
  end

  describe "product details page - template preview" do
    setup [:setup_admin_conn, :create_product]

    test "prepares preview, creates an enrollment, and pushes a launch event", %{
      conn: conn,
      admin: admin,
      product: product
    } do
      user = insert(:user, author: admin, email: admin.email)
      conn = conn |> log_in_user(user) |> log_in_author(admin)

      {:ok, view, _html} = live(conn, product_route(product.slug))
      preview_url = "/sections/#{product.slug}"

      render_click(element(view, "button[phx-click='template_preview']"))

      assert_push_event(view, "template-preview-open", %{url: ^preview_url})

      enrollment =
        Oli.Delivery.Sections.get_enrollment(product.slug, user.id, filter_by_status: false)
        |> Oli.Repo.preload(:context_roles)

      assert enrollment.status == :enrolled

      assert Enum.any?(
               enrollment.context_roles,
               &(&1.id == Lti_1p3.Roles.ContextRoles.get_role(:context_learner).id)
             )

      assert has_element?(view, "a[href='/sections/#{product.slug}']", "Open Preview")
    end

    test "shows an error when the author has no linked learner account", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, product_route(product.slug))

      render_click(element(view, "button[phx-click='template_preview']"))

      assert render(view) =~ "Preview requires a linked learner account for the current author"
      refute has_element?(view, "a[href='/sections/#{product.slug}']", "Open Preview")
    end

    test "reuses the existing enrollment on repeated launch", %{
      conn: conn,
      admin: admin,
      product: product
    } do
      user = insert(:user, author: admin, email: admin.email)
      conn = conn |> log_in_user(user) |> log_in_author(admin)

      {:ok, view, _html} = live(conn, product_route(product.slug))
      preview_url = "/sections/#{product.slug}"

      render_click(element(view, "button[phx-click='template_preview']"))
      assert_push_event(view, "template-preview-open", %{url: ^preview_url})

      render_click(element(view, "button[phx-click='template_preview']"))
      assert_push_event(view, "template-preview-open", %{url: ^preview_url})

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
  end

  describe "product details content component - source materials badge" do
    test "shows tokenized badge when updates are available", _ctx do
      product = build(:section, type: :blueprint)
      updates = %{123 => %{id: 123}, 456 => %{id: 456}}

      html =
        render_component(&Content.render/1, %{
          product: product,
          updates: updates,
          changeset:
            Phoenix.Component.to_form(Oli.Delivery.Sections.Section.changeset(product, %{})),
          save: "save"
        })

      assert html =~ "Manage Source Materials"
      assert html =~ ~s(id="manage-source-materials-updates-badge")
      assert html =~ ~s(bg-Fill-Buttons-fill-primary)
      assert html =~ ~s(text-Text-text-white)
      assert html =~ "2 updates"
    end

    test "does not show badge when no updates are available", _ctx do
      product = build(:section, type: :blueprint)

      html =
        render_component(&Content.render/1, %{
          product: product,
          updates: %{},
          changeset:
            Phoenix.Component.to_form(Oli.Delivery.Sections.Section.changeset(product, %{})),
          save: "save"
        })

      refute html =~ "Manage Source Materials"
      refute html =~ ~s(id="manage-source-materials-updates-badge")
      refute html =~ "updates</span>"
    end
  end
end
