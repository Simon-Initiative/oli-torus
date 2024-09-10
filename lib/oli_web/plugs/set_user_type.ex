defmodule Oli.Plugs.SetUserType do
  import Plug.Conn

  @behaviour Plug

  def init(user_type), do: user_type

  def call(conn, user_type), do: assign(conn, :user_type, user_type)
end
