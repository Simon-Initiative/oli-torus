defmodule OliWeb.Common.DeviceDetectionTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias OliWeb.Common.DeviceDetection

  # User agent strings for testing
  @iphone_ua "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
  @android_phone_ua "Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36"
  @ipad_ua "Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
  @android_tablet_ua "Mozilla/5.0 (Linux; Android 12; Tablet) AppleWebKit/537.36"
  @desktop_windows_ua "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  @desktop_mac_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

  describe "is_mobile?/1" do
    test "returns true for iPhone user agent string" do
      assert DeviceDetection.is_mobile?(@iphone_ua) == true
    end

    test "returns true for Android phone user agent string" do
      assert DeviceDetection.is_mobile?(@android_phone_ua) == true
    end

    test "returns false for iPad user agent string" do
      assert DeviceDetection.is_mobile?(@ipad_ua) == false
    end

    test "returns false for Android tablet user agent string" do
      assert DeviceDetection.is_mobile?(@android_tablet_ua) == false
    end

    test "returns false for desktop Windows user agent string" do
      assert DeviceDetection.is_mobile?(@desktop_windows_ua) == false
    end

    test "returns false for desktop Mac user agent string" do
      assert DeviceDetection.is_mobile?(@desktop_mac_ua) == false
    end

    test "returns false for nil" do
      assert DeviceDetection.is_mobile?(nil) == false
    end

    test "returns false for empty string" do
      assert DeviceDetection.is_mobile?("") == false
    end

    test "returns true for Conn with iPhone user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @iphone_ua)

      assert DeviceDetection.is_mobile?(conn) == true
    end

    test "returns false for Conn with iPad user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @ipad_ua)

      assert DeviceDetection.is_mobile?(conn) == false
    end

    test "returns false for Conn with desktop user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_windows_ua)

      assert DeviceDetection.is_mobile?(conn) == false
    end

    test "returns false for Conn without user agent header" do
      conn = conn(:get, "/")

      assert DeviceDetection.is_mobile?(conn) == false
    end

    # Note: Socket connect_info is only available during mount, so we can't test
    # Socket directly. Socket functionality is tested through SetDeviceType plug tests.
  end

  describe "is_tablet?/1" do
    test "returns true for iPad user agent string" do
      assert DeviceDetection.is_tablet?(@ipad_ua) == true
    end

    test "returns true for Android tablet user agent string" do
      assert DeviceDetection.is_tablet?(@android_tablet_ua) == true
    end

    test "returns false for iPhone user agent string" do
      assert DeviceDetection.is_tablet?(@iphone_ua) == false
    end

    test "returns false for Android phone user agent string" do
      assert DeviceDetection.is_tablet?(@android_phone_ua) == false
    end

    test "returns false for desktop Windows user agent string" do
      assert DeviceDetection.is_tablet?(@desktop_windows_ua) == false
    end

    test "returns false for desktop Mac user agent string" do
      assert DeviceDetection.is_tablet?(@desktop_mac_ua) == false
    end

    test "returns false for nil" do
      assert DeviceDetection.is_tablet?(nil) == false
    end

    test "returns false for empty string" do
      assert DeviceDetection.is_tablet?("") == false
    end

    test "returns true for Conn with iPad user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @ipad_ua)

      assert DeviceDetection.is_tablet?(conn) == true
    end

    test "returns false for Conn with iPhone user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @iphone_ua)

      assert DeviceDetection.is_tablet?(conn) == false
    end

    test "returns false for Conn without user agent header" do
      conn = conn(:get, "/")

      assert DeviceDetection.is_tablet?(conn) == false
    end

    # Note: Socket connect_info is only available during mount, so we can't test
    # Socket directly. Socket functionality is tested through SetDeviceType plug tests.
  end

  describe "is_mobile_or_tablet?/1" do
    test "returns true for iPhone user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@iphone_ua) == true
    end

    test "returns true for Android phone user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@android_phone_ua) == true
    end

    test "returns true for iPad user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@ipad_ua) == true
    end

    test "returns true for Android tablet user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@android_tablet_ua) == true
    end

    test "returns false for desktop Windows user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@desktop_windows_ua) == false
    end

    test "returns false for desktop Mac user agent string" do
      assert DeviceDetection.is_mobile_or_tablet?(@desktop_mac_ua) == false
    end

    test "returns true for Conn with iPhone user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @iphone_ua)

      assert DeviceDetection.is_mobile_or_tablet?(conn) == true
    end

    test "returns true for Conn with iPad user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @ipad_ua)

      assert DeviceDetection.is_mobile_or_tablet?(conn) == true
    end

    test "returns false for Conn with desktop user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_windows_ua)

      assert DeviceDetection.is_mobile_or_tablet?(conn) == false
    end

    # Note: Socket connect_info is only available during mount, so we can't test
    # Socket directly. Socket functionality is tested through SetDeviceType plug tests.
  end

  describe "is_desktop?/1" do
    test "returns true for desktop Windows user agent string" do
      assert DeviceDetection.is_desktop?(@desktop_windows_ua) == true
    end

    test "returns true for desktop Mac user agent string" do
      assert DeviceDetection.is_desktop?(@desktop_mac_ua) == true
    end

    test "returns false for iPhone user agent string" do
      assert DeviceDetection.is_desktop?(@iphone_ua) == false
    end

    test "returns false for Android phone user agent string" do
      assert DeviceDetection.is_desktop?(@android_phone_ua) == false
    end

    test "returns false for iPad user agent string" do
      assert DeviceDetection.is_desktop?(@ipad_ua) == false
    end

    test "returns false for Android tablet user agent string" do
      assert DeviceDetection.is_desktop?(@android_tablet_ua) == false
    end

    test "returns true for nil (defaults to desktop)" do
      assert DeviceDetection.is_desktop?(nil) == true
    end

    test "returns true for empty string (defaults to desktop)" do
      assert DeviceDetection.is_desktop?("") == true
    end

    test "returns true for Conn with desktop user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_windows_ua)

      assert DeviceDetection.is_desktop?(conn) == true
    end

    test "returns false for Conn with iPhone user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @iphone_ua)

      assert DeviceDetection.is_desktop?(conn) == false
    end

    test "returns true for Conn without user agent header (defaults to desktop)" do
      conn = conn(:get, "/")

      assert DeviceDetection.is_desktop?(conn) == true
    end

    # Note: Socket connect_info is only available during mount, so we can't test
    # Socket directly. Socket functionality is tested through SetDeviceType plug tests.
  end

  describe "device_type/1" do
    test "returns :mobile for iPhone user agent string" do
      assert DeviceDetection.device_type(@iphone_ua) == :mobile
    end

    test "returns :mobile for Android phone user agent string" do
      assert DeviceDetection.device_type(@android_phone_ua) == :mobile
    end

    test "returns :tablet for iPad user agent string" do
      assert DeviceDetection.device_type(@ipad_ua) == :tablet
    end

    test "returns :tablet for Android tablet user agent string" do
      assert DeviceDetection.device_type(@android_tablet_ua) == :tablet
    end

    test "returns :desktop for desktop Windows user agent string" do
      assert DeviceDetection.device_type(@desktop_windows_ua) == :desktop
    end

    test "returns :desktop for desktop Mac user agent string" do
      assert DeviceDetection.device_type(@desktop_mac_ua) == :desktop
    end

    test "returns :desktop for nil (defaults to desktop)" do
      assert DeviceDetection.device_type(nil) == :desktop
    end

    test "returns :desktop for empty string (defaults to desktop)" do
      assert DeviceDetection.device_type("") == :desktop
    end

    test "returns :mobile for Conn with iPhone user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @iphone_ua)

      assert DeviceDetection.device_type(conn) == :mobile
    end

    test "returns :tablet for Conn with iPad user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @ipad_ua)

      assert DeviceDetection.device_type(conn) == :tablet
    end

    test "returns :desktop for Conn with desktop user agent" do
      conn =
        conn(:get, "/")
        |> put_req_header("user-agent", @desktop_windows_ua)

      assert DeviceDetection.device_type(conn) == :desktop
    end

    test "returns :desktop for Conn without user agent header (defaults to desktop)" do
      conn = conn(:get, "/")

      assert DeviceDetection.device_type(conn) == :desktop
    end

    # Note: Socket connect_info is only available during mount, so we can't test
    # Socket directly. Socket functionality is tested through SetDeviceType plug tests.
  end
end
