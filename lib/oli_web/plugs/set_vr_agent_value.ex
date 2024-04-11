defmodule Oli.Plugs.SetVrAgentValue do
  import Plug.Conn

  def init(_params), do: nil

  def call(conn, _params) do
    with user_agent when not is_nil(user_agent) <-
           get_user_agent_from_req_headers?(conn.req_headers),
         true <- Oli.VrLookupCache.exists(user_agent) do
      assign(conn, :vr_agent_active, true)
    else
      _ ->
        conn
    end
  end

  defp get_user_agent_from_req_headers?(req_headers) do
    Enum.reduce_while(req_headers, nil, fn {k, v}, acc ->
      if k == "user-agent", do: {:halt, v}, else: {:cont, acc}
    end)
  end
end
