defmodule Oli.Plugs.SetSidebar do
  @moduledoc """
  This plug sets the sidebar_expanded session key based on the sidebar_expanded parameter.
  Is used to initially render the sidebar nav in the expanded or collapsed state.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_session(
      :sidebar_expanded,
      Oli.Utils.string_to_boolean(conn.params["sidebar_expanded"] || "true")
    )
  end
end
