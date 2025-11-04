defmodule OliWeb.LiveSessionPlugs.RequireEnrollmentTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Phoenix.LiveView
  alias OliWeb.LiveSessionPlugs.RequireEnrollment

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    user = insert(:user)
    author = insert(:author)

    %{user: user, author: author, conn: conn}
  end

  describe "on_mount: :default with section_slug" do
    test "redirects learner to enroll page when user is not enrolled",
         %{
           user: user
         } do
      section = insert(:section)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, current_author: nil, section: section}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 socket
               )

      assert {:redirect, %{to: redirected_to}} = redirected_socket.redirected
      assert redirected_to == "/sections/#{section.slug}/enroll"
    end

    test "redirects to login when current_user is nil" do
      section = insert(:section, requires_enrollment: false)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: nil, section: section}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 socket
               )

      assert {:redirect, %{to: redirected_to}} = redirected_socket.redirected
      assert redirected_to == "/users/log_in?request_path=%2Fsections%2F#{section.slug}"
    end

    test "redirects to student workspace when user enrollment is not allowed" do
      section = insert(:section, open_and_free: true, registration_open: false)

      user = insert(:user)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, section: section, flash: %{}}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 socket
               )

      assert {:redirect, %{to: "/workspaces/student"}} = redirected_socket.redirected

      assert redirected_socket.assigns.flash["error"] == "You are not enrolled in this course"
    end

    test "allows access for admin author", %{author: author} do
      author = %{author | system_role_id: 2}

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_author: author}
      }

      assert {:cont, updated_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => "test_section"},
                 %{},
                 socket
               )

      assert updated_socket.assigns.is_enrolled == true
    end

    test "allows access when user is enrolled", %{user: user} do
      section = insert(:section)
      insert(:enrollment, user: user, section: section)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, current_author: nil}
      }

      assert {:cont, updated_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 socket
               )

      assert updated_socket.assigns.is_enrolled == true
    end
  end

  describe "on_mount: :default without section_slug" do
    test "continues without checking enrollment" do
      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}}
      }

      assert {:cont, ^socket} = RequireEnrollment.on_mount(:default, %{}, %{}, socket)
    end
  end
end
