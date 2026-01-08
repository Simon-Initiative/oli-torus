defmodule OliWeb.Plugs.StoreSettingsReturnTo do
  @moduledoc """
  Stores a same-origin referer path when navigating to user settings so the
  LiveView can return the user to the previous page.
  """

  import Plug.Conn

  @excluded_paths ["/users/settings", "/users/log_in"]

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/users/settings", method: "GET"} = conn, _opts) do
    conn = fetch_query_params(conn)
    return_to = Map.get(conn.params, "settings_return_to")
    referer = get_req_header(conn, "referer") |> List.first()

    case normalize_return_to(return_to) || parse_referer_path(referer, conn.host) do
      nil ->
        conn

      path ->
        maybe_store_path(conn, path)
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

  defp normalize_return_to(nil), do: nil

  defp normalize_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/") and !String.starts_with?(path, "//"), do: path, else: nil
  end

  defp maybe_store_path(conn, path) do
    if should_store_path?(path), do: put_session(conn, "settings_return_to", path), else: conn
  end

  defp should_store_path?(path),
    do: not Enum.any?(@excluded_paths, &String.starts_with?(path, &1))
end
