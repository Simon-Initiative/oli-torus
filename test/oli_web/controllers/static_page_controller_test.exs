defmodule OliWeb.StaticPageControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")

    assert html_response(conn, 200) =~ "Welcome to"
    assert html_response(conn, 200) =~ "For Instructors"
    assert html_response(conn, 200) =~ "For Course Authors"
  end

  describe "set_session" do
    test "stores the message id correctly when the session value is not set", %{conn: conn} do
      conn = post(conn, Routes.static_page_path(conn, :set_session), dismissed_message: "1")

      assert get_session(conn, :dismissed_messages) == [1]
    end

    test "stores the message id correctly when the session value is not empty", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{dismissed_messages: [2]})

      conn = post(conn, Routes.static_page_path(conn, :set_session), dismissed_message: "1")

      assert get_session(conn, :dismissed_messages) == [1, 2]
    end
  end

  describe "local timezone" do
    test "loads timezone script when local timezone is not set", %{conn: conn} do
      conn = get(conn, "/")

      assert html_response(conn, 200) =~ "/js/timezone.js"
    end

    test "does not load timezone script when local timezone is set", context do
      {:ok, conn: conn, ctx: _} = set_timezone(context)

      conn = get(conn, "/")

      refute html_response(conn, 200) =~ "/js/timezone.js"
    end
  end

  describe "keep alive" do
    test "redirects when user is not logged in", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :keep_alive))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/session/new?request_path=%2Fkeep-alive\">redirected"
    end

    test "returns ok when user is logged in", conn do
      {:ok, conn: conn, user: _} = user_conn(conn)
      conn = get(conn, Routes.static_page_path(conn, :keep_alive))

      assert response(conn, 200) =~ "Ok"
    end

    test "redirects when author is not logged in", %{conn: conn} do
      conn = get(conn, Routes.author_keep_alive_path(conn, :keep_alive))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fkeep-alive\">redirected"
    end

    test "returns ok when author is logged in", conn do
      {:ok, conn: conn, author: _} = author_conn(conn)
      conn = get(conn, Routes.author_keep_alive_path(conn, :keep_alive))

      assert response(conn, 200) =~ "Ok"
    end
  end

  describe "update_timezone" do
    test "updates the author timezone preference and redirects correctly", context do
      {:ok, conn: conn, author: author} = author_conn(context)
      new_timezone = "America/Montevideo"
      redirect_to = Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)

      conn =
        post(conn, Routes.static_page_path(conn, :update_timezone), %{
          timezone: %{
            timezone: new_timezone,
            redirect_to: redirect_to
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Timezone updated successfully."

      assert Accounts.get_author_preference(author.id, :timezone) == new_timezone
      assert redirected_to(conn, 302) == redirect_to
    end

    test "updates the user timezone preference and redirects correctly", context do
      {:ok, conn: conn, user: user} = user_conn(context)
      new_timezone = "America/Montevideo"
      redirect_to = ~p"/workspaces/student"

      conn =
        post(conn, Routes.static_page_path(conn, :update_timezone), %{
          timezone: %{
            timezone: new_timezone,
            redirect_to: redirect_to
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Timezone updated successfully."

      assert Accounts.get_user_preference(user.id, :timezone) == new_timezone
      assert redirected_to(conn, 302) == redirect_to
    end

    test "updates the user timezone preference and redirects to the index page when the path is invalid",
         context do
      {:ok, conn: conn, user: user} = user_conn(context)
      new_timezone = "America/Montevideo"

      conn =
        post(conn, Routes.static_page_path(conn, :update_timezone), %{
          timezone: %{
            timezone: new_timezone,
            redirect_to: "invalid_path"
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Timezone updated successfully."

      assert Accounts.get_user_preference(user.id, :timezone) == new_timezone
      assert redirected_to(conn, 302) == Routes.static_page_path(conn, :index)
    end
  end

  describe "student login" do
    test "shows student login view", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert response(conn, 200) =~ "OLI Torus"

      assert response(conn, 200) =~ "Easily access and participate in your enrolled courses"
      assert response(conn, 200) =~ "Need an account?"
    end

    test "shows 'access my courses' link if user is logged in and is an independent learner",
         conn do
      {:ok, conn: conn, user: _user} = user_conn(conn)

      conn = get(conn, Routes.static_page_path(conn, :index))

      assert response(conn, 200) =~ "Access my courses"
    end

    test "shows informative text if user is logged in and is an LMS user", %{conn: conn} do
      {:ok, conn: conn, user: user} =
        user_conn(%{conn: conn}, %{name: "Kevin Durant", independent_learner: false})

      insert(:lti_params, user_id: user.id)

      conn = get(conn, Routes.static_page_path(conn, :index))

      assert response(conn, 200) =~
               "Navigate to your institution’s LMS to access your online course."
    end
  end

  describe "enrollment info" do
    test "shows enrollment info in students login", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert response(conn, 200) =~ "Course Enrollment"
      assert response(conn, 200) =~ "Locate your Enrollment Link"

      assert response(conn, 200) =~
               "Your instructor will provide an enrollment link to sign up and access your course. Please contact your instructor if you have not received this link or have misplaced it."

      assert response(conn, 200) =~ "Create an Account"

      assert response(conn, 200) =~
               "Follow your enrollment link to the account creation page where you will create a user ID and password."

      assert response(conn, 200) =~ "Still need an account?"

      assert response(conn, 200) =~
               "Visit our FAQs document"

      assert response(conn, 200) =~
               "for help enrolling or setting up your Torus student account. If you require further assistance, please"

      assert response(conn, 200) =~ "contact our support team."
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "does not allow access to the index page when logged in as an admin", %{
      conn: conn
    } do
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Admins are not allowed to access this page."

      assert html_response(conn, 302) =~
               "You are being <a href=\"/workspaces/course_author\">redirected"
    end
  end
end
