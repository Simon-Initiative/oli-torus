defmodule OliWeb.ObjectivesLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Oli.Factory
  import Mox

  alias Oli.Test.MockHTTP
  alias OliWeb.Router.Helpers, as: Routes

  @expected_headers %{"Content-Type" => "application/x-www-form-urlencoded"}

  defp live_view_grades_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, section_slug)
  end

  defp create_section(_conn) do
    jwk = jwk_fixture()

    registration =
      insert(:lti_registration, %{
        auth_token_url: "https://example.com",
        tool_jwk_id: jwk.id,
        client_id: "0001",
        auth_server: "https://example.com"
      })

    deployment = insert(:lti_deployment, %{registration: registration})
    section = insert(:section, %{lti_1p3_deployment: deployment})

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing manage LMS grades view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fgrades%2Flms&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_grades_route(section_slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to ", %{conn: conn, section: section} do
      section_slug = section.slug
      conn = get(conn, live_view_grades_route(section_slug))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fgrades%2Flms&section=#{section_slug}"

      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "test connection" do
    setup [:admin_conn, :create_section]

    test "returns success when the connection to the LMS is successful", %{
      conn: conn,
      section: section
    } do
      url = section.lti_1p3_deployment.registration.auth_token_url

      MockHTTP
      |> expect(:post, fn ^url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200
         }}
      end)

      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element("button[phx-click=\"test_connection\"]")
      |> render_click()

      assert has_element?(view, "samp", "Starting test")
      assert has_element?(view, "samp", "Requesting access token...")
      assert has_element?(view, "samp", "Received access token")
    end
  end

  describe "export grades" do
    setup [:admin_conn, :section_with_assessment]

    test "download grades file without grades succesfully", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

      view
      |> element(
        "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)}\"]",
        "Download Gradebook"
      )
      |> render_click()

      conn =
        get(
          conn,
          Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)
        )

      assert response(conn, 200) =~ "Student,Progress test revision\r\n    Points Possible\r\n"
    end
  end

  # describe "update line items" do
  #   setup [:admin_conn, :create_section]

  #   test "fails when cant update line items", %{conn: conn, section: section} do

  #     MockHTTP
  #     |> expect(:post, fn ^auth_token_url, _body, @expected_headers ->
  #       {:ok,
  #        %HTTPoison.Response{
  #          status_code: 200
  #        }}
  #     end)

  #     {:ok, view, _html} = live(conn, live_view_grades_route(section.slug))

  #     view
  #     |> element(
  #       "a[phx-click=\"send_line_items\"]",
  #       "Update LMS Line Items"
  #     )
  #     |> render_click()
  #   end
  # end
end
