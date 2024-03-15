defmodule Oli.Plugs.SetVrAgentValue do
  import Plug.Conn
  alias Oli.Accounts.User

  def init(_params) do
  end

  def call(conn, _params) do
    case Map.get(conn.assigns, :current_user) do
      %User{id: user_id} ->
        vr_agent_active = Oli.VrLookupCache.get_vr_user_agent_value(user_id)
        assign(conn, :vr_agent_active, vr_agent_active)

      _ ->
        conn
    end
  end
end
