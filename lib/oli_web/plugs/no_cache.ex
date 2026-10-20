defmodule Oli.Plugs.NoCache do
  @moduledoc """
  Prevents storage of dynamic responses, including redirects and handled errors.

  Register before routing so the final header cannot accidentally be weakened by
  a controller. Static assets are served before this plug in the endpoint.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{private: %{oli_no_cache: true}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_private(:oli_no_cache, true)
    |> register_before_send(fn conn ->
      case {conn.status, conn.private[:oli_public_content], conn.resp_cookies,
            get_resp_header(conn, "set-cookie")} do
        {200, true, cookies, []} when map_size(cookies) == 0 -> conn
        _ -> put_resp_header(conn, "cache-control", "private, no-store")
      end
    end)
  end

  @doc """
  Preserves the existing caching policy for a successful, non-sensitive response.

  Only use for public content (such as public verification keys or external media
  bytes), never personalized content. Errors and responses setting cookies remain
  non-storable. This does not make a response publicly cacheable by itself.
  """
  @spec public_content(Plug.Conn.t()) :: Plug.Conn.t()
  def public_content(conn), do: put_private(conn, :oli_public_content, true)
end
