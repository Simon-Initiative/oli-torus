defmodule OliWeb.ProductsControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts.SystemRole

  setup %{conn: conn} do
    admin =
      insert(:author, %{
        system_role_id: SystemRole.role_id().system_admin
      })

    product =
      insert(:section, %{
        type: :blueprint,
        title: "Alpha Product",
        slug: "alpha-product",
        requires_payment: true,
        amount: Money.new(15, "USD")
      })

    other_product =
      insert(:section, %{
        type: :blueprint,
        title: "Beta Product",
        slug: "beta-product",
        requires_payment: false
      })

    archived_product =
      insert(:section, %{
        type: :blueprint,
        title: "Archived Product",
        slug: "archived-product",
        status: :archived
      })

    tag_one = insert(:tag, name: "Onboarding")
    tag_two = insert(:tag, name: "Calculus")

    insert(:section_tag, section: product, tag: tag_one)
    insert(:section_tag, section: product, tag: tag_two)

    conn = log_in_author(conn, admin)

    %{
      conn: conn,
      admin: admin,
      product: product,
      other_product: other_product,
      archived_product: archived_product
    }
  end

  describe "export_csv/2" do
    test "admin can download CSV with all products", %{conn: conn, product: product} do
      conn = get(conn, ~p"/authoring/products/export")

      assert response(conn, 200)

      [content_type] = get_resp_header(conn, "content-type")
      assert content_type == "text/csv"

      csv_content = response(conn, 200)

      assert String.contains?(
               csv_content,
               "Title,Product ID,Tags,Created,Requires Payment,Base Project,Base Project ID,Status"
             )

      assert String.contains?(csv_content, product.title)
      assert String.contains?(csv_content, product.slug)
      assert String.contains?(csv_content, "Calculus")
      assert String.contains?(csv_content, "Onboarding")
    end

    test "respects text search filters", %{
      conn: conn,
      product: product,
      other_product: other_product
    } do
      conn = get(conn, ~p"/authoring/products/export?text_search=#{product.slug}")
      csv_content = response(conn, 200)

      assert String.contains?(csv_content, product.title)
      refute String.contains?(csv_content, other_product.title)
    end

    test "excludes archived products unless explicitly requested", %{
      conn: conn,
      admin: admin,
      archived_product: archived_product
    } do
      conn = get(conn, ~p"/authoring/products/export")
      csv_content = response(conn, 200)
      refute String.contains?(csv_content, archived_product.title)

      conn =
        build_conn()
        |> log_in_author(admin)
        |> get(~p"/authoring/products/export?include_archived=true")

      csv_content = response(conn, 200)
      assert String.contains?(csv_content, archived_product.title)
    end

    test "includes payment data formatted consistently", %{conn: conn, product: product} do
      conn = get(conn, ~p"/authoring/products/export?text_search=#{product.slug}")
      csv_content = response(conn, 200)

      assert String.contains?(csv_content, "$15.00")
    end
  end

  describe "export_usage_csv/2" do
    setup do
      author = insert(:author)
      admin = insert(:author, %{system_role_id: SystemRole.role_id().system_admin})
      content_admin = insert(:author, %{system_role_id: SystemRole.role_id().content_admin})
      project = insert(:project, authors: [author])

      product =
        insert(:section, %{
          type: :blueprint,
          title: "Template For Usage",
          slug: "template-for-usage",
          base_project: project
        })

      tagged_section =
        insert(:section, %{
          type: :enrollable,
          title: "Usage Section One",
          slug: "usage-section-one",
          base_project: project,
          blueprint_id: product.id
        })

      insert(:section, %{
        type: :enrollable,
        title: "Usage Section Two",
        slug: "usage-section-two",
        base_project: project,
        blueprint_id: product.id
      })

      tag = insert(:tag, name: "UsageTag")
      insert(:section_tag, section: tagged_section, tag: tag)

      %{
        author: author,
        admin: admin,
        content_admin: content_admin,
        product: product
      }
    end

    test "non-admin export excludes tags column", %{conn: conn, author: author, product: product} do
      conn =
        conn
        |> log_in_author(author)
        |> get(~p"/authoring/products/#{product.slug}/usage/export")

      assert response(conn, 200)
      csv = response(conn, 200)
      [header | _] = String.split(csv, "\n", trim: true)

      refute String.contains?(header, "Tags")
      assert String.contains?(header, "Project Version")
    end

    test "admin export includes tags column", %{conn: conn, admin: admin, product: product} do
      conn =
        conn
        |> log_in_author(admin)
        |> get(~p"/authoring/products/#{product.slug}/usage/export")

      assert response(conn, 200)
      csv = response(conn, 200)
      [header | _] = String.split(csv, "\n", trim: true)

      assert String.contains?(header, "Tags")
      assert String.contains?(csv, "Usage Section One")
    end

    test "content admin can export usage csv", %{
      conn: conn,
      content_admin: content_admin,
      product: product
    } do
      conn =
        conn
        |> log_in_author(content_admin)
        |> get(~p"/authoring/products/#{product.slug}/usage/export")

      assert response(conn, 200)
      csv = response(conn, 200)
      [header | _] = String.split(csv, "\n", trim: true)

      assert String.contains?(header, "Tags")
      assert String.contains?(csv, "Usage Section One")
    end

    test "empty usage export returns headers only", %{
      conn: conn,
      author: author,
      product: product
    } do
      conn =
        conn
        |> log_in_author(author)
        |> get(~p"/authoring/products/#{product.slug}/usage/export?active_today=true")

      csv = response(conn, 200)
      lines = String.split(csv, "\n", trim: true)

      assert length(lines) == 1
      assert hd(lines) =~ "Title,Section ID"
    end
  end

  describe "preview_launch/2" do
    setup do
      author = insert(:author)
      admin = insert(:author, %{system_role_id: SystemRole.role_id().content_admin})
      project = insert(:project, authors: [author])
      admin_project = insert(:project, authors: [admin])

      author_product =
        insert(:section, %{
          type: :blueprint,
          title: "Template Preview Author",
          slug: "template-preview-author",
          base_project: project,
          status: :active
        })

      admin_product =
        insert(:section, %{
          type: :blueprint,
          title: "Template Preview Admin",
          slug: "template-preview-admin",
          base_project: admin_project,
          status: :active
        })

      %{
        author: author,
        admin: admin,
        author_product: author_product,
        admin_product: admin_product
      }
    end

    test "authorized author without current_user is logged in as the section hidden instructor",
         %{
           conn: conn,
           author: author,
           author_product: product
         } do
      conn =
        conn
        |> log_in_author(author)
        |> get(~p"/authoring/products/#{product.slug}/preview_launch")

      assert redirected_to(conn) == "/sections/#{product.slug}"
      assert get_session(conn, :template_preview_mode)
      assert get_session(conn, :template_preview_section_slug) == product.slug

      assert get_session(conn, :template_preview_return_to) ==
               "/authoring/products/#{product.slug}"

      hidden_user = Oli.Repo.get!(Oli.Accounts.User, get_session(conn, :current_user_id))

      assert hidden_user.hidden
      assert Oli.Delivery.Sections.is_instructor?(hidden_user, product.slug)
    end

    test "reuses the same hidden instructor across repeated preview launches", %{
      conn: conn,
      author: author,
      author_product: product
    } do
      conn =
        conn
        |> log_in_author(author)
        |> get(~p"/authoring/products/#{product.slug}/preview_launch")

      first_hidden_user_id = get_session(conn, :current_user_id)

      conn =
        build_conn()
        |> log_in_author(author)
        |> get(~p"/authoring/products/#{product.slug}/preview_launch")

      assert redirected_to(conn) == "/sections/#{product.slug}"
      assert get_session(conn, :current_user_id) == first_hidden_user_id
    end

    test "authorized admin without current_user also reuses the section hidden instructor model",
         %{
           conn: conn,
           admin: admin,
           admin_product: product
         } do
      conn =
        conn
        |> log_in_author(admin)
        |> get(~p"/authoring/products/#{product.slug}/preview_launch")

      assert redirected_to(conn) == "/sections/#{product.slug}"

      hidden_user = Oli.Repo.get!(Oli.Accounts.User, get_session(conn, :current_user_id))

      assert hidden_user.hidden
      assert Oli.Delivery.Sections.is_instructor?(hidden_user, product.slug)
    end

    test "authorized author with current_user sets template preview session and preserves user",
         %{
           conn: conn,
           author: author,
           author_product: product
         } do
      user = insert(:user)

      conn =
        conn
        |> log_in_author(author)
        |> log_in_user(user)
        |> get(~p"/authoring/products/#{product.slug}/preview_launch")

      assert redirected_to(conn) == "/sections/#{product.slug}"
      assert get_session(conn, :current_user_id) == user.id
      assert get_session(conn, :template_preview_mode)
      assert get_session(conn, :template_preview_section_slug) == product.slug
    end
  end

  describe "preview_exit/2" do
    test "clears template preview session without logging out a non-hidden user", %{conn: conn} do
      author = insert(:author)
      user = insert(:user)

      conn =
        conn
        |> log_in_author(author)
        |> log_in_user(user)
        |> init_test_session(%{
          template_preview_mode: true,
          template_preview_section_slug: "template-preview-author",
          template_preview_return_to: "/authoring/products/template-preview-author"
        })
        |> delete(~p"/authoring/template_preview/exit")

      assert redirected_to(conn) == "/authoring/products/template-preview-author"
      assert get_session(conn, :current_user_id) == user.id
      refute get_session(conn, :template_preview_mode)
      refute get_session(conn, :template_preview_section_slug)
      refute get_session(conn, :template_preview_return_to)
    end

    test "logs out a hidden user while preserving author session", %{conn: conn} do
      author = insert(:author)
      hidden_user = insert(:user, hidden: true)

      conn =
        conn
        |> log_in_author(author)
        |> log_in_user(hidden_user)
        |> init_test_session(%{
          template_preview_mode: true,
          template_preview_section_slug: "template-preview-author",
          template_preview_return_to: "/authoring/products/template-preview-author"
        })
        |> delete(~p"/authoring/template_preview/exit")

      assert redirected_to(conn) == "/authoring/products/template-preview-author"
      assert get_session(conn, :current_author_id) == author.id
      refute get_session(conn, :current_user_id)
      refute get_session(conn, :template_preview_mode)
    end
  end
end
