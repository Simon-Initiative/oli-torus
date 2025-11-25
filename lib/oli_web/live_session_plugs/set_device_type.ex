defmodule OliWeb.LiveSessionPlugs.SetDeviceType do
  @moduledoc """
  This live session plug sets the device type in the socket assigns based on the user agent.
  It uses OliWeb.Common.DeviceDetection to determine if the device is mobile, tablet, or desktop.
  """

  import Phoenix.Component, only: [assign: 2]
  alias OliWeb.Common.DeviceDetection

  def on_mount(:default, _params, _session, socket) do
    device_type = DeviceDetection.device_type(socket)

    socket =
      assign(socket,
        is_mobile: device_type == :mobile,
        is_tablet: device_type == :tablet,
        is_desktop: device_type == :desktop
      )

    {:cont, socket}
  end
end
