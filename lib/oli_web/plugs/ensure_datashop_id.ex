defmodule OliWeb.Plugs.EnsureDatashopId do
  @moduledoc """
  This plug ensures that a unique datashop session ID is present in the session and assigned to the
  connection. If the session already has a datashop session ID, it will be used. Otherwise, a new
  datashop session ID will be generated and put into the current session.
  """
  import Plug.Conn

  @datashop_session_key :datashop_session_id

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @datashop_session_key) do
      nil ->
        datashop_session_id = generate_datashop_session_id()

        conn
        |> put_session(@datashop_session_key, datashop_session_id)
        |> assign(:datashop_session_id, datashop_session_id)

      datashop_session_id ->
        assign(conn, :datashop_session_id, datashop_session_id)
    end
  end

  defp generate_datashop_session_id do
    # Generate a unique session ID
    UUID.uuid4()
  end
end
