defmodule OliWeb.Plugs.PutSessionExpirationTimeCookie do
  import Plug.Conn
  alias Pow.Store.Backend.MnesiaCache

  def init(_params), do: nil

  def call(conn, _params) do
    with [_, fingerprint: fingerprint] <- Map.get(conn.private, :pow_session_metadata),
         {:atomic, [expire]} <- search_expiration_by_fingerprint(fingerprint) do
      conn
      |> delete_resp_cookie("_oli_session_expiration_time", http_only: false)
      |> put_resp_cookie("_oli_session_expiration_time", "#{expire}", http_only: false)
    else
      _ ->
        conn
    end
  end

  defp search_expiration_by_fingerprint(fingerprint) do
    :mnesia.transaction(fn ->
      :mnesia.select(
        MnesiaCache,
        [
          {{MnesiaCache, ["credentials", :_],
            {{:_, [inserted_at: :_, fingerprint: :"$1"]}, :"$2"}}, [{:==, :"$1", fingerprint}],
           [:"$2"]}
        ]
      )
    end)
  end
end
