defmodule OliWeb.LiveSessionPlugs.SetDeviceType do
  @moduledoc """
  This live session plug sets the device type in the socket assigns based on the user agent.
  It uses OliWeb.Common.DeviceDetection to determine if the device is mobile, tablet, or desktop.
  """

  import Phoenix.Component, only: [assign: 2]
  alias OliWeb.Common.DeviceDetection

  def on_mount(:default, _params, _session, socket) do
    device_type =
      case Phoenix.LiveView.get_connect_info(socket, :user_agent) do
        user_agent when is_binary(user_agent) ->
          DeviceDetection.device_type(user_agent)

        _ ->
          # Default to desktop when connect_info is not available
          # (During disconnected mount phase, before websocket connects, connect_info is not available)
          :desktop
      end

    socket =
      assign(socket,
        is_mobile: device_type == :mobile,
        is_tablet: device_type == :tablet,
        is_desktop: device_type == :desktop
      )

    {:cont, socket}
  end
end
