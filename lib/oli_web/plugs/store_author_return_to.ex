defmodule OliWeb.Plugs.StoreAuthorReturnTo do
  @moduledoc """
  Stores a same-origin referer path when navigating to the author-linking flow so
  the user can be returned to the page they came from after linking accounts.
  """

  import Plug.Conn

  @excluded_paths ["/users/link_account", "/authors/log_in"]

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/users/link_account", method: "GET"} = conn, _opts) do
    referer = get_req_header(conn, "referer") |> List.first()

    case parse_referer_path(referer, conn.host) do
      nil -> conn
      path -> maybe_store_path(conn, path)
    end
  end

  def call(conn, _opts), do: conn

  defp parse_referer_path(nil, _host), do: nil

  defp parse_referer_path(referer, host) do
    case URI.parse(referer) do
      %URI{host: ^host, path: path, query: query} when is_binary(path) ->
        build_path(path, query)

      _ ->
        nil
    end
  end

  defp build_path(path, nil), do: path
  defp build_path(path, ""), do: path
  defp build_path(path, query), do: path <> "?" <> query

  defp maybe_store_path(conn, path) do
    if should_store_path?(path), do: put_session(conn, "author_return_to", path), else: conn
  end

  defp should_store_path?(path),
    do: not Enum.any?(@excluded_paths, &String.starts_with?(path, &1))
end
