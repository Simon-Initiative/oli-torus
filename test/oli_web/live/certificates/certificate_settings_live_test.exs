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

  defp delivery_lv_route(section_slug) do
    ~p"/sections/#{section_slug}/certificate_settings"
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

      # Displays sub-menu pointing to Templates
      assert has_element?(
               view,
               ~s{a[href="/workspaces/course_author/#{project.slug}/products?sidebar_expanded=true"] > div[class~="bg-[#E6E9F2]"][class~="dark:bg-[#222126]"][class~="hover:!bg-[#E6E9F2]"][class~="hover:dark:!bg-[#222126]"]},
               "Templates"
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

  describe "certificate settings live - delivery section" do
    setup do
      section =
        insert(:section, %{certificate_enabled: true, open_and_free: true, type: :enrollable})

      certificate = insert(:certificate, section: section)

      {:ok, %{section: section, certificate: certificate}}
    end

    test "renders certificate settings read only for instructors", ctx do
      %{conn: conn, section: section} = ctx
      {:ok, conn: conn, instructor: instructor} = instructor_conn(%{conn: conn})

      Sections.enroll(instructor.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      {:ok, view, _html} = live(conn, delivery_lv_route(section.slug))

      assert has_element?(view, "fieldset[disabled]")
      refute has_element?(view, "button", "Save Thresholds")
    end

    test "allows any admin to edit certificate settings in a section", ctx do
      %{conn: conn, section: section, certificate: certificate} = ctx
      {:ok, conn: conn, content_admin: _admin} = content_admin_conn(%{conn: conn})

      {:ok, view, _html} = live(conn, delivery_lv_route(section.slug))

      refute has_element?(view, "fieldset[disabled]")
      assert has_element?(view, "button", "Save Thresholds")

      view
      |> element("#certificate_form")
      |> render_submit(%{
        "certificate" => %{
          "min_percentage_for_completion" => "70",
          "min_percentage_for_distinction" => "90",
          "required_discussion_posts" => "3",
          "required_class_notes" => "4",
          "section_id" => "#{section.id}",
          "requires_instructor_approval" => "true",
          "assessments_apply_to" => "all"
        }
      })

      updated_certificate = Oli.Delivery.Certificates.get_certificate(certificate.id)

      assert updated_certificate.min_percentage_for_completion == 70
      assert updated_certificate.min_percentage_for_distinction == 90
      assert updated_certificate.required_discussion_posts == 3
      assert updated_certificate.required_class_notes == 4
      assert updated_certificate.requires_instructor_approval
    end
  end
end
