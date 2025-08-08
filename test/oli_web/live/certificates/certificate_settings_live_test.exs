defmodule OliWeb.Certificates.CertificateSettingsLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections

  defp workspaces_lv_route(project_slug, product_slug) do
    ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}/certificate_settings"
  end

  defp authoring_lv_route(product_slug) do
    ~p"/authoring/products/#{product_slug}/certificate_settings"
  end

  describe "certificate settings live - workspaces" do
    setup do
      project = insert(:project)
      product = insert(:section, certificate_enabled: false, base_project: project)

      {:ok, %{product: product, project: project}}
    end

    test "renders left-bottom sub-menu", ctx do
      %{conn: conn, product: product, project: project} = ctx
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      {:ok, view, _html} = live(conn, workspaces_lv_route(project.slug, product.slug))

      # Displays sub-menu pointing to Products
      assert has_element?(
               view,
               ~s{a[href="/workspaces/course_author/#{project.slug}/products?sidebar_expanded=true"] > div[class~="bg-[#E6E9F2]"][class~="dark:bg-[#222126]"][class~="hover:!bg-[#E6E9F2]"][class~="hover:dark:!bg-[#222126]"]},
               "Products"
             )

      # Displays project title
      assert has_element?(
               view,
               ~s{div[class~="block"][class~="truncate"][class~="text-[14px]"][class~="h-[24px]"][class~="font-bold"][class~="ml-5"][class~="dark:text-[#B8B4BF]"][class~="text-[#353740]"][class~="tracking-[-1%]"][class~="leading-6"][class~="uppercase"]},
               project.title
             )
    end

    test "renders tabs and content when certificate is enabled", ctx do
      %{conn: conn, product: product, project: project} = ctx
      # Enabling certificate_enabled
      {:ok, product} = Sections.update_section(product, %{certificate_enabled: true})
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      {:ok, view, _html} = live(conn, workspaces_lv_route(project.slug, product.slug))

      ## Tabs
      [
        {"1", "thresholds", "Thresholds"},
        {"2", "design", "Design"},
        {"3", "credentials_issued", "Credentials Issued"}
      ]
      |> Enum.each(fn {i, active_tab, text} ->
        assert has_element?(
                 view,
                 ~s{#certificate_settings_tabs > div:nth-child(#{i}) > a[href='/workspaces/course_author/#{project.slug}/products/#{product.slug}/certificate_settings?active_tab=#{active_tab}']},
                 "#{text}"
               )
      end)

      ## Content - initial content is the Thresholds component
      assert has_element?(
               view,
               "div[data-phx-component='1']",
               "Customize the conditions students must meet to receive a certificate."
             )
    end

    test "doesn't render tabs and content when certificate is disabled", ctx do
      %{conn: conn, product: product, project: project} = ctx
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      {:ok, view, _html} = live(conn, workspaces_lv_route(project.slug, product.slug))

      ## No Tabs
      [
        {"1", "thresholds", "Thresholds"},
        {"2", "design", "Design"},
        {"3", "credentials_issued", "Credentials Issued"}
      ]
      |> Enum.each(fn {i, active_tab, text} ->
        refute has_element?(
                 view,
                 ~s{#certificate_settings_tabs > div:nth-child(#{i}) > a[href='/workspaces/course_author/#{project.slug}/products/#{product.slug}/certificate_settings?active_tab=#{active_tab}']},
                 "#{text}"
               )
      end)

      ## No Content - initial content is the Thresholds component
      refute has_element?(
               view,
               "div[data-phx-component='1']",
               "Customize the conditions students must meet to receive a certificate."
             )
    end
  end

  describe "certificate settings live - authoring" do
    setup do
      product = insert(:section, certificate_enabled: false)

      {:ok, %{product: product}}
    end

    test "renders tabs and content when certificate is enabled", ctx do
      %{conn: conn, product: product} = ctx
      # Enabling certificate_enabled
      {:ok, product} = Sections.update_section(product, %{certificate_enabled: true})
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      {:ok, view, _html} = live(conn, authoring_lv_route(product.slug))

      ## Tabs
      [
        {"1", "thresholds", "Thresholds"},
        {"2", "design", "Design"},
        {"3", "credentials_issued", "Credentials Issued"}
      ]
      |> Enum.each(fn {i, active_tab, text} ->
        assert has_element?(
                 view,
                 ~s{#certificate_settings_tabs > div:nth-child(#{i}) > a[href='/authoring/products/#{product.slug}/certificate_settings?active_tab=#{active_tab}']},
                 "#{text}"
               )
      end)

      ## Content - initial content is the Thresholds component
      assert has_element?(
               view,
               "div[data-phx-component='1']",
               "Customize the conditions students must meet to receive a certificate."
             )
    end

    test "doesn't render tabs and content when certificate is disabled", ctx do
      %{conn: conn, product: product} = ctx
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
      {:ok, view, _html} = live(conn, authoring_lv_route(product.slug))

      ## No Tabs
      [
        {"1", "thresholds", "Thresholds"},
        {"2", "design", "Design"},
        {"3", "credentials_issued", "Credentials Issued"}
      ]
      |> Enum.each(fn {i, active_tab, text} ->
        refute has_element?(
                 view,
                 ~s{#certificate_settings_tabs > div:nth-child(#{i}) > a[href='/authoring/products/#{product.slug}/certificate_settings?active_tab=#{active_tab}']},
                 "#{text}"
               )
      end)

      ## Content - initial content is the Thresholds component
      refute has_element?(
               view,
               "div[data-phx-component='1']",
               "Customize the conditions students must meet to receive a certificate."
             )
    end
  end
end
