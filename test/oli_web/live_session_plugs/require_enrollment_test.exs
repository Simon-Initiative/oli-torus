defmodule OliWeb.LiveSessionPlugs.RequireEnrollmentTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Phoenix.LiveView
  alias OliWeb.LiveSessionPlugs.RequireEnrollment
  alias Oli.Delivery.Sections

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    user = insert(:user)
    author = insert(:author)

    %{user: user, author: author, conn: conn}
  end

  describe "on_mount: :default with section that doesn't require enrollment" do
    test "auto-enrolls user and sets is_enrolled when section requires_enrollment is false and user is independent",
         %{
           user: user
         } do
      section = insert(:section, requires_enrollment: false)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, current_author: nil, section: section}
      }

      assert {:cont, updated_socket} = RequireEnrollment.on_mount(:default, %{}, %{}, socket)
      assert updated_socket.assigns.is_enrolled == true

      assert Sections.is_enrolled?(user.id, section.slug)
    end

    test "falls through to default clause when current_user is nil" do
      section = insert(:section, requires_enrollment: false)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: nil, section: section}
      }

      assert {:cont, ^socket} = RequireEnrollment.on_mount(:default, %{}, %{}, socket)
    end

    test "redirects to student workspace when user enrollment is not allowed" do
      section = insert(:section, open_and_free: true, requires_enrollment: false)

      user = insert(:user, independent_learner: false)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, section: section, flash: %{}}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(:default, %{}, %{}, socket)

      assert redirected_socket.redirected
    end

    test "skipss auto-enrollment when user is already enrolled" do
      section = insert(:section, requires_enrollment: false)

      user = insert(:user)
      insert(:enrollment, user: user, section: section)

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, current_author: nil, section: section}
      }

      assert {:cont, updated_socket} = RequireEnrollment.on_mount(:default, %{}, %{}, socket)
      assert updated_socket.assigns.is_enrolled == true
      assert Sections.is_enrolled?(user.id, section.slug)
    end
  end

  describe "on_mount: :default with section_slug" do
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

    test "redirects to login when no user is present" do
      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: nil, flash: %{}}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => "test_section"},
                 %{},
                 socket
               )

      assert redirected_socket.redirected
    end

    test "redirects to student workspace when user is not enrolled", %{user: user} do
      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, current_user: user, current_author: nil, flash: %{}}
      }

      assert {:halt, redirected_socket} =
               RequireEnrollment.on_mount(
                 :default,
                 %{"section_slug" => "nonexistent_section"},
                 %{},
                 socket
               )

      assert redirected_socket.redirected
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
