defmodule OliWeb.Api.MediaProxyController do
  @moduledoc """
  Proxies external GIF bytes for the janus-image GIF player when browser CORS blocks direct fetch.
  """

  use OliWeb, :controller

  @max_bytes 10 * 1024 * 1024
  @request_timeout_ms 15_000

  @blocked_hosts ~w(
    localhost
    metadata.google.internal
    metadata.goog
  )

  def show(conn, %{"url" => url}) when is_binary(url) do
    with true <- authenticated?(conn),
         {:ok, body} <- fetch_gif(url) do
      conn
      |> put_resp_content_type("image/gif")
      |> put_resp_header("cache-control", "private, max-age=300")
      |> send_resp(200, body)
    else
      false -> send_resp(conn, 401, "")
      {:error, :forbidden} -> send_resp(conn, 403, "")
      {:error, :bad_request} -> send_resp(conn, 400, "")
      {:error, _} -> send_resp(conn, 502, "")
    end
  end

  def show(conn, _params), do: send_resp(conn, 400, "")

  defp authenticated?(conn),
    do: not is_nil(conn.assigns[:current_author]) or not is_nil(conn.assigns[:current_user])

  defp fetch_gif(url) when is_binary(url) do
    with {:ok, uri} <- parse_url(url),
         :ok <- validate_gif_url(uri),
         :ok <- validate_host(uri),
         :ok <- validate_resolved_ips(uri.host),
         {:ok, body} <- http_get(uri),
         :ok <- validate_size(body),
         :ok <- validate_gif_bytes(body) do
      {:ok, body}
    else
      {:error, reason} when reason in [:blocked_host, :blocked_ip] -> {:error, :forbidden}
      {:error, reason} when reason in [:request_failed, :upstream_error] -> {:error, :upstream}
      {:error, _} -> {:error, :bad_request}
    end
  end

  defp fetch_gif(_), do: {:error, :bad_request}

  defp parse_url(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp validate_gif_url(%URI{path: path}) when is_binary(path) do
    if Regex.match?(~r/\.gif(?:[?#].*)?$/i, path), do: :ok, else: {:error, :not_gif_url}
  end

  defp validate_gif_url(_), do: {:error, :not_gif_url}

  defp validate_host(%URI{host: host}) when is_binary(host) do
    normalized = String.downcase(host)

    cond do
      normalized in @blocked_hosts -> {:error, :blocked_host}
      String.ends_with?(normalized, ".localhost") -> {:error, :blocked_host}
      true -> :ok
    end
  end

  defp validate_resolved_ips(host) do
    host
    |> resolve_ips()
    |> Enum.reduce_while(:ok, fn ip, :ok ->
      if blocked_ip?(ip), do: {:halt, {:error, :blocked_ip}}, else: {:cont, :ok}
    end)
  end

  defp validate_size(body) when byte_size(body) <= @max_bytes, do: :ok
  defp validate_size(_), do: {:error, :too_large}

  defp validate_gif_bytes(<<"GIF87a", _::binary>>), do: :ok
  defp validate_gif_bytes(<<"GIF89a", _::binary>>), do: :ok
  defp validate_gif_bytes(_), do: {:error, :invalid_gif}

  defp resolve_ips(host) do
    case :inet.gethostbyname(String.to_charlist(host)) do
      {:ok, {:hostent, _name, _aliases, _addrtype, _length, addresses}} -> addresses
      {:error, _} -> []
    end
  end

  defp blocked_ip?({127, _, _, _}), do: true
  defp blocked_ip?({0, _, _, _}), do: true
  defp blocked_ip?({10, _, _, _}), do: true
  defp blocked_ip?({172, b, _, _}) when b in 16..31, do: true
  defp blocked_ip?({192, 168, _, _}), do: true
  defp blocked_ip?({169, 254, _, _}), do: true
  defp blocked_ip?({_, _, _, _} = ip), do: ip_in_cgnat?(ip)
  defp blocked_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp blocked_ip?({0xFE, 0x80, _, _, _, _, _, _}), do: true
  defp blocked_ip?({0xFC, _, _, _, _, _, _, _}), do: true
  defp blocked_ip?({0xFD, _, _, _, _, _, _, _}), do: true
  defp blocked_ip?(_), do: false

  defp ip_in_cgnat?({100, b, _, _}) when b in 64..127, do: true
  defp ip_in_cgnat?(_), do: false

  defp http_get(%URI{} = uri) do
    case HTTPoison.get(URI.to_string(uri), [],
           follow_redirect: false,
           recv_timeout: @request_timeout_ms,
           timeout: @request_timeout_ms
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in 400..599 ->
        {:error, :upstream_error}

      {:error, %HTTPoison.Error{}} ->
        {:error, :request_failed}
    end
  end
end
