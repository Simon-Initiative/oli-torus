defmodule OliWeb.Plugs.PreloadPlatformRoles do
  import Plug.Conn

  alias Oli.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    case Map.get(conn.assigns, :current_user) do
      nil ->
        conn
      user ->
        assign(conn, :user, Repo.preload(user, :platform_roles))
    end
  end
end
