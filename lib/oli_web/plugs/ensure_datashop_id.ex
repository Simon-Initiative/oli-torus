defmodule OliWeb.Plugs.EnsureDatashopId do
  @moduledoc """
  This plug ensures that a unique datashop session ID is present in the session and assigned to the
  connection. If the session already has a datashop session ID, it will be used. Otherwise, a new
  datashop session ID will be generated and put into the current session.

  If the session is older than the configured session lifetime, a new datashop session ID will be
  generated and put into the current session.
  """
  import Plug.Conn
  import Oli.Utils, only: [trap_nil: 1]

  # 30 minutes
  @datashop_session_ttl_sec 30 * 60
  @datashop_session_id_key :datashop_session_id
  @datashop_session_timestamp_key :datashop_session_updated_at

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, datashop_session_id} <- get_session(conn, @datashop_session_id_key) |> trap_nil(),
         {:ok, datashop_session_updated_at} <-
           get_session(conn, @datashop_session_timestamp_key) |> trap_nil(),
         {:ok, datashop_session_updated_at} <-
           normalize_timestamp(datashop_session_updated_at) |> trap_nil(),
         true <-
           System.os_time(:second) - datashop_session_updated_at < @datashop_session_ttl_sec do
      # use existing datashop id and update the timestamp in the session
      timestamp = System.os_time(:second)

      conn
      |> put_session(@datashop_session_timestamp_key, timestamp)
      |> assign(:datashop_session_id, datashop_session_id)
    else
      _ ->
        # session is older than the configured session lifetime, generate a new datashop id
        datashop_session_id = UUID.uuid4()
        timestamp = System.os_time(:second)

        conn
        |> put_session(@datashop_session_id_key, datashop_session_id)
        |> put_session(@datashop_session_timestamp_key, timestamp)
        |> assign(:datashop_session_id, datashop_session_id)
    end
  end

  defp normalize_timestamp(timestamp) when is_integer(timestamp), do: timestamp

  # Backward-compat: tuple times lack date context; treat as expired.
  defp normalize_timestamp({_hour, _minute, _second}), do: nil

  defp normalize_timestamp(_), do: nil
end
