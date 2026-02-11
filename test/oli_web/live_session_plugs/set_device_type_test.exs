defmodule OliWeb.LiveSessionPlugs.SetDeviceTypeTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.LiveSessionPlugs.SetDeviceType
  alias Phoenix.LiveView.Socket

  # User agent strings for testing
  @iphone_ua "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
  @android_phone_ua "Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36"
  @ipad_ua "Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
  @android_tablet_ua "Mozilla/5.0 (Linux; Android 12; SM-T970) AppleWebKit/537.36"
  @desktop_windows_ua "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  @desktop_mac_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

  describe "on_mount/4" do
    test "assigns is_mobile: true for iPhone user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @iphone_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == true
      assert updated_socket.assigns.is_tablet == false
      assert updated_socket.assigns.is_desktop == false
    end

    test "assigns is_mobile: true for Android phone user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @android_phone_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == true
      assert updated_socket.assigns.is_tablet == false
      assert updated_socket.assigns.is_desktop == false
    end

    test "assigns is_tablet: true for iPad user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @ipad_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == false
      assert updated_socket.assigns.is_tablet == true
      assert updated_socket.assigns.is_desktop == false
    end

    test "assigns is_tablet: true for Android tablet user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @android_tablet_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == false
      assert updated_socket.assigns.is_tablet == true
      assert updated_socket.assigns.is_desktop == false
    end

    test "assigns is_desktop: true for Windows desktop user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @desktop_windows_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == false
      assert updated_socket.assigns.is_tablet == false
      assert updated_socket.assigns.is_desktop == true
    end

    test "assigns is_desktop: true for Mac desktop user agent" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}},
        private: %{connect_info: %{user_agent: @desktop_mac_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.is_mobile == false
      assert updated_socket.assigns.is_tablet == false
      assert updated_socket.assigns.is_desktop == true
    end

    test "preserves existing socket assigns" do
      socket = %Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{
          __changed__: %{},
          existing_assign: "preserved",
          current_user: %{id: 1}
        },
        private: %{connect_info: %{user_agent: @iphone_ua}}
      }

      assert {:cont, updated_socket} =
               SetDeviceType.on_mount(:default, %{}, %{}, socket)

      assert updated_socket.assigns.existing_assign == "preserved"
      assert updated_socket.assigns.current_user.id == 1
      assert updated_socket.assigns.is_mobile == true
    end
  end
end
