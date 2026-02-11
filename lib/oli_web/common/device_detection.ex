defmodule OliWeb.Common.DeviceDetection do
  @moduledoc """
  Utility functions for detecting device types from user agent.

  This module provides server-side device detection capabilities that can be used
  in LiveViews and controllers to determine if a user is accessing the application
  from a mobile device, tablet, or desktop.

  ## Usage

      # In a LiveView mount function (recommended - accepts socket directly)
      is_mobile = OliWeb.Common.DeviceDetection.is_mobile?(socket)

      # In a controller or plug (recommended - accepts conn directly)
      is_mobile = OliWeb.Common.DeviceDetection.is_mobile?(conn)

      # Or with a user agent string directly
      user_agent = get_connect_info(socket, :user_agent) || ""
      is_mobile = OliWeb.Common.DeviceDetection.is_mobile?(user_agent)
  """

  alias Plug.Conn
  alias Phoenix.LiveView.Socket

  @mobile_patterns ~r/(android|webos|iphone|ipod|blackberry|iemobile|opera mini|mobile)/i
  @tablet_patterns ~r/(ipad|tablet|playbook|silk)/i
  # Android tablet model patterns (e.g., SM-T* for Samsung tablets, GT-P* for older Samsung tablets)
  @android_tablet_patterns ~r/(SM-T\d+|GT-P\d+|SCH-I800|SC-01C|SHW-M180W|SGH-T849|GT-N\d+|SM-P\d+)/i

  @doc """
  Determines if a user agent string indicates a mobile device.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, or a user agent string.
  Returns `true` for mobile phones and smartphones, `false` otherwise.
  Note: This function returns `false` for tablets. Use `is_tablet?/1` to detect tablets.

  ## Examples

      # With a socket (LiveView)
      is_mobile = OliWeb.Common.DeviceDetection.is_mobile?(socket)

      # With a conn (Controller/Plug)
      is_mobile = OliWeb.Common.DeviceDetection.is_mobile?(conn)

      # With a user agent string
      iex> OliWeb.Common.DeviceDetection.is_mobile?("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)")
      true

      iex> OliWeb.Common.DeviceDetection.is_mobile?("Mozilla/5.0 (Linux; Android 12; SM-G991B)")
      true

      iex> OliWeb.Common.DeviceDetection.is_mobile?("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      false

      iex> OliWeb.Common.DeviceDetection.is_mobile?("Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X)")
      false

      iex> OliWeb.Common.DeviceDetection.is_mobile?(nil)
      false
  """
  @spec is_mobile?(Conn.t() | Socket.t() | String.t() | nil) :: boolean()
  def is_mobile?(%Conn{} = conn) do
    conn
    |> extract_user_agent()
    |> is_mobile?()
  end

  def is_mobile?(%Socket{} = socket) do
    socket
    |> extract_user_agent()
    |> is_mobile?()
  end

  def is_mobile?(nil), do: false
  def is_mobile?(""), do: false

  def is_mobile?(user_agent) when is_binary(user_agent) do
    # Exclude tablets from mobile detection
    if is_tablet?(user_agent) do
      false
    else
      String.downcase(user_agent)
      |> String.match?(@mobile_patterns)
    end
  end

  def is_mobile?(_), do: false

  @doc """
  Determines if a user agent string indicates a tablet device.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, or a user agent string.
  Returns `true` for tablets (iPad, Android tablets, etc.), `false` otherwise.

  ## Examples

      # With a socket (LiveView)
      is_tablet = OliWeb.Common.DeviceDetection.is_tablet?(socket)

      # With a conn (Controller/Plug)
      is_tablet = OliWeb.Common.DeviceDetection.is_tablet?(conn)

      # With a user agent string
      iex> OliWeb.Common.DeviceDetection.is_tablet?("Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X)")
      true

      iex> OliWeb.Common.DeviceDetection.is_tablet?("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)")
      false

      iex> OliWeb.Common.DeviceDetection.is_tablet?("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      false
  """
  @spec is_tablet?(Conn.t() | Socket.t() | String.t() | nil) :: boolean()
  def is_tablet?(%Conn{} = conn) do
    conn
    |> extract_user_agent()
    |> is_tablet?()
  end

  def is_tablet?(%Socket{} = socket) do
    socket
    |> extract_user_agent()
    |> is_tablet?()
  end

  def is_tablet?(nil), do: false
  def is_tablet?(""), do: false

  def is_tablet?(user_agent) when is_binary(user_agent) do
    user_agent_lower = String.downcase(user_agent)

    # Check standard tablet patterns
    matches_tablet_pattern = String.match?(user_agent_lower, @tablet_patterns)

    # Check Android tablet model patterns (case-sensitive check on original)
    matches_android_tablet = String.match?(user_agent, @android_tablet_patterns)

    matches_tablet_pattern || matches_android_tablet
  end

  def is_tablet?(_), do: false

  @doc """
  Determines if a user agent string indicates a mobile device or tablet.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, or a user agent string.
  This is a convenience function that returns `true` for both mobile phones and tablets.

  ## Examples

      # With a socket (LiveView)
      is_mobile_or_tablet = OliWeb.Common.DeviceDetection.is_mobile_or_tablet?(socket)

      # With a conn (Controller/Plug)
      is_mobile_or_tablet = OliWeb.Common.DeviceDetection.is_mobile_or_tablet?(conn)

      # With a user agent string
      iex> OliWeb.Common.DeviceDetection.is_mobile_or_tablet?("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)")
      true

      iex> OliWeb.Common.DeviceDetection.is_mobile_or_tablet?("Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X)")
      true

      iex> OliWeb.Common.DeviceDetection.is_mobile_or_tablet?("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      false
  """
  @spec is_mobile_or_tablet?(Conn.t() | Socket.t() | String.t() | nil) :: boolean()
  def is_mobile_or_tablet?(%Conn{} = conn), do: is_mobile_or_tablet?(extract_user_agent(conn))

  def is_mobile_or_tablet?(%Socket{} = socket),
    do: is_mobile_or_tablet?(extract_user_agent(socket))

  def is_mobile_or_tablet?(user_agent), do: is_mobile?(user_agent) || is_tablet?(user_agent)

  @doc """
  Determines if a user agent string indicates a desktop device.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, or a user agent string.
  Returns `true` if the device is neither mobile nor tablet.

  ## Examples

      # With a socket (LiveView)
      is_desktop = OliWeb.Common.DeviceDetection.is_desktop?(socket)

      # With a conn (Controller/Plug)
      is_desktop = OliWeb.Common.DeviceDetection.is_desktop?(conn)

      # With a user agent string
      iex> OliWeb.Common.DeviceDetection.is_desktop?("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      true

      iex> OliWeb.Common.DeviceDetection.is_desktop?("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
      true

      iex> OliWeb.Common.DeviceDetection.is_desktop?("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)")
      false
  """
  @spec is_desktop?(Conn.t() | Socket.t() | String.t() | nil) :: boolean()
  def is_desktop?(%Conn{} = conn), do: is_desktop?(extract_user_agent(conn))
  def is_desktop?(%Socket{} = socket), do: is_desktop?(extract_user_agent(socket))
  def is_desktop?(user_agent), do: not is_mobile_or_tablet?(user_agent)

  @doc """
  Returns the device type as an atom.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, or a user agent string.
  Returns `:mobile`, `:tablet`, or `:desktop`.

  ## Examples

      # With a socket (LiveView)
      device_type = OliWeb.Common.DeviceDetection.device_type(socket)

      # With a conn (Controller/Plug)
      device_type = OliWeb.Common.DeviceDetection.device_type(conn)

      # With a user agent string
      iex> OliWeb.Common.DeviceDetection.device_type("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)")
      :mobile

      iex> OliWeb.Common.DeviceDetection.device_type("Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X)")
      :tablet

      iex> OliWeb.Common.DeviceDetection.device_type("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
      :desktop
  """
  @spec device_type(Conn.t() | Socket.t() | String.t() | nil) :: :mobile | :tablet | :desktop
  def device_type(%Conn{} = conn), do: device_type(extract_user_agent(conn))
  def device_type(%Socket{} = socket), do: device_type(extract_user_agent(socket))

  def device_type(user_agent) do
    cond do
      is_mobile?(user_agent) -> :mobile
      is_tablet?(user_agent) -> :tablet
      true -> :desktop
    end
  end

  # Private helper function to extract user agent from conn or socket
  defp extract_user_agent(%Conn{} = conn) do
    Conn.get_req_header(conn, "user-agent")
    |> List.first()
    |> case do
      nil -> ""
      user_agent -> user_agent
    end
  end

  defp extract_user_agent(%Socket{} = socket) do
    case socket.private do
      %{connect_info: %{user_agent: user_agent}} when is_binary(user_agent) -> user_agent
      %{connect_info: %{user_agent: user_agent}} when user_agent in [nil, ""] -> ""
      _ -> ""
    end
  end
end
