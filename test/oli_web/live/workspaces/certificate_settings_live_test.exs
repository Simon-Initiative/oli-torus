defmodule OliWeb.Workspaces.CourseAuthor.Certificates.CertificateSettingsLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "certificate settings live" do
    setup do
      project = insert(:project)

      product =
        insert(
          :section,
          %{
            title: "Test Product",
            certificate_enabled: false,
            type: :blueprint,
            base_project: project
          }
        )

      {:ok, %{product: product, project: project}}
    end

    test "renders the CertificateSettingsComponent", %{
      conn: conn,
      product: product,
      project: project
    } do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/workspaces/course_author/#{project.slug}/products/#{product.slug}/certificate_settings"
        )

      assert has_element?(view, "div[data-phx-component]")
    end
  end
end
