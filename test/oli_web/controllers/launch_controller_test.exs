defmodule OliWeb.LaunchControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  describe "launch controller as guest user" do
    setup [:guest_conn, :section_with_assessment]

    test "join endpoint redirects correctly to the enrollment view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll?auto_enroll_as_guest=true\">redirected"

      conn = get(conn, ~p"/sections/#{section.slug}/enroll?auto_enroll_as_guest=true")

      response = html_response(conn, 200)

      assert response =~ "Begin Lesson"
      assert response =~ "You will be enrolled as a <b>Guest</b>"
    end

    test "join endpoint redirects to unauthorized page if section is not open and free", %{
      conn: conn
    } do
      section = insert(:section, open_and_free: false, requires_enrollment: true)

      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/unauthorized\">redirected"
    end

    test "auto enroll endpoint redirects to first page of course section", %{
      conn: conn,
      guest: guest,
      section: section,
      page_revision: page_revision
    } do
      insert(:enrollment, user: guest, section: section)
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          ~p"/sections/#{section.slug}/auto_enroll?auto_enroll_as_guest=true",
          %{
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/page/#{page_revision.slug}\">redirected"
    end

    test "join endpoint redirects to section overview page if user is already enrolled", %{
      conn: conn,
      guest: guest,
      section: section
    } do
      insert(:enrollment, user: guest, section: section)

      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll?auto_enroll_as_guest=true\">redirected"

      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          ~p"/sections/#{section.slug}/enroll?auto_enroll_as_guest=true",
          %{
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}\">redirected"
    end
  end

  describe "launch controller as authenticated user" do
    setup [:user_conn, :section_with_assessment]

    test "join endpoint redirects correctly to the enrollment view",
         %{
           conn: conn,
           section: section
         } do
      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll?auto_enroll_as_guest=false\">redirected"

      conn = get(conn, ~p"/sections/#{section.slug}/enroll?auto_enroll_as_guest=false")

      response = html_response(conn, 200)

      assert response =~ "Enroll"
    end

    test "join endpoint redirects to unauthorized page if section is not open and free", %{
      conn: conn
    } do
      section = insert(:section, open_and_free: false, requires_enrollment: true)

      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/unauthorized\">redirected"
    end

    test "auto enroll endpoint redirects to first page of course section", %{
      conn: conn,
      user: user,
      section: section,
      page_revision: page_revision
    } do
      insert(:enrollment, user: user, section: section)
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          ~p"/sections/#{section.slug}/auto_enroll?auto_enroll_as_guest=false",
          %{
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/page/#{page_revision.slug}\">redirected"
    end

    test "join endpoint redirects to section overview page if user is already enrolled", %{
      conn: conn,
      user: user,
      section: section
    } do
      insert(:enrollment, user: user, section: section)

      conn = get(conn, ~p"/sections/#{section.slug}/join")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll?auto_enroll_as_guest=false\">redirected"

      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          ~p"/sections/#{section.slug}/enroll?auto_enroll_as_guest=false",
          %{
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}\">redirected"
    end
  end
end
