defmodule OliWeb.Api.Helpers do
  import Plug.Conn

  def error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

  def is_valid_api_key?(conn, verify_fn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> encoded_key] ->
        case Base.decode64(encoded_key) do
          {:ok, decoded} ->
            verify_fn.(decoded)

          _ ->
            false
        end

      _ ->
        false
    end
  end

  def get_api_namespace(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> encoded_key] ->
        case Base.decode64(encoded_key) do
          {:ok, decoded} ->
            Oli.Interop.get_namespace(decoded)

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
