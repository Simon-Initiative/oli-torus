defmodule Oli.GoogleDocs.Client do
  @moduledoc """
  Thin HTTP wrapper responsible for downloading Google Docs Markdown exports with
  validation, retry, and size guardrails as defined in the docs import spec.
  """

  require Logger

  alias HTTPoison.Response

  @export_url "https://docs.google.com/document/d"
  @file_id_pattern ~r/^[A-Za-z0-9_-]{10,}$/
  @default_headers [
    {"accept", "text/markdown"},
    {"user-agent",
     "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"}
  ]
  @default_timeout 5_000
  @default_recv_timeout 15_000
  @default_retry_delay_ms 200
  @default_max_attempts 2
  @default_max_bytes 10 * 1024 * 1024
  @hackney_pool :google_docs_import
  @default_pool_options [max_connections: 8, timeout: 5_000]

  @type fetch_option ::
          {:max_bytes, pos_integer()}
          | {:max_attempts, pos_integer()}
          | {:retry_delay_ms, non_neg_integer()}
          | {:timeout, non_neg_integer()}
          | {:recv_timeout, non_neg_integer()}
          | {:headers, [{binary(), binary()}]}
          | {:hackney, keyword()}

  @type fetch_result :: %{
          body: binary(),
          bytes: non_neg_integer(),
          content_type: binary() | nil,
          headers: [{binary(), binary()}],
          url: binary(),
          file_id: binary()
        }

  @type fetch_error ::
          {:invalid_file_id, :blank | :format | :not_binary}
          | {:http_status, non_neg_integer(), Response.t()}
          | {:http_error, term()}
          | {:body_too_large, %{bytes: non_neg_integer(), limit: non_neg_integer()}}

  @doc """
  Fetches the Markdown export for the given Google Docs `file_id`.

  Returns `{:ok, result}` when the request succeeds and the payload does not exceed the size cap.
  Returns `{:error, reason}` for validation, HTTP, or size failures.
  """
  @spec fetch_markdown(any(), [fetch_option()]) :: {:ok, fetch_result()} | {:error, fetch_error()}
  def fetch_markdown(file_id, opts \\ [])

  def fetch_markdown(file_id, _opts) when not is_binary(file_id),
    do: {:error, {:invalid_file_id, :not_binary}}

  def fetch_markdown(file_id, opts) do
    with {:ok, normalized_id} <- normalize_file_id(file_id),
         url <- build_export_url(normalized_id),
         max_bytes <- Keyword.get(opts, :max_bytes, @default_max_bytes),
         {:ok, response} <- request(url, normalized_id, opts),
         :ok <- enforce_success(response, normalized_id, opts),
         :ok <- enforce_size(response, max_bytes) do
      {:ok,
       %{
         body: response.body,
         bytes: byte_size(response.body),
         content_type: content_type(response.headers),
         headers: response.headers,
         url: url,
         file_id: normalized_id
       }}
    end
  end

  defp normalize_file_id(file_id) do
    trimmed = String.trim(file_id)

    cond do
      trimmed == "" ->
        {:error, {:invalid_file_id, :blank}}

      URI.parse(trimmed).scheme in ["http", "https"] ->
        {:error, {:invalid_file_id, :format}}

      Regex.match?(@file_id_pattern, trimmed) ->
        {:ok, trimmed}

      true ->
        {:error, {:invalid_file_id, :format}}
    end
  end

  defp build_export_url(file_id) do
    "#{@export_url}/#{file_id}/export?format=md"
  end

  defp request(url, file_id, opts) do
    max_attempts = opts |> Keyword.get(:max_attempts, @default_max_attempts) |> max(1)
    max_redirects = opts |> Keyword.get(:max_redirects, 3) |> max(0)
    do_request(url, file_id, opts, 1, max_attempts, max_redirects)
  end

  defp do_request(url, file_id, opts, attempt, max_attempts, redirects_remaining) do
    case Oli.HTTP.http().get(url, request_headers(opts), request_options(opts)) do
      {:ok, %Response{} = response} ->
        if success_status?(response.status_code) do
          {:ok, response}
        else
          handle_unsuccessful_response(
            response,
            url,
            file_id,
            opts,
            attempt,
            max_attempts,
            redirects_remaining
          )
        end

      {:error, reason} ->
        handle_error_response(
          reason,
          url,
          file_id,
          opts,
          attempt,
          max_attempts,
          redirects_remaining
        )
    end
  end

  defp handle_unsuccessful_response(
         %Response{} = response,
         url,
         file_id,
         opts,
         attempt,
         max_attempts,
         redirects_remaining
       ) do
    cond do
      redirect_status?(response.status_code) and redirects_remaining > 0 ->
        case redirect_target(response, url) do
          {:ok, new_url} ->
            do_request(new_url, file_id, opts, attempt, max_attempts, redirects_remaining - 1)

          {:error, error_reason} ->
            {:error, error_reason}
        end

      retriable_status?(response.status_code) and attempt < max_attempts ->
        backoff(attempt, opts)
        do_request(url, file_id, opts, attempt + 1, max_attempts, redirects_remaining)

      true ->
        {:error, {:http_status, response.status_code, redact_body(response)}}
    end
  end

  defp handle_error_response(
         reason,
         url,
         file_id,
         opts,
         attempt,
         max_attempts,
         redirects_remaining
       ) do
    if retriable_error?(reason) and attempt < max_attempts do
      backoff(attempt, opts)
      do_request(url, file_id, opts, attempt + 1, max_attempts, redirects_remaining)
    else
      {:error, {:http_error, redacted_reason(reason)}}
    end
  end

  defp enforce_success(
         %Response{status_code: status, headers: headers} = response,
         _file_id,
         _opts
       ) do
    cond do
      success_status?(status) ->
        :ok

      redirect_status?(status) ->
        location = get_header(headers, "location")
        {:error, {:http_redirect, status, location}}

      true ->
        {:error, {:http_status, status, redact_body(response)}}
    end
  end

  defp enforce_size(%Response{headers: headers, body: body}, max_bytes) do
    body_size = byte_size(body)

    cond do
      header_size(headers) > max_bytes ->
        {:error, {:body_too_large, %{bytes: header_size(headers), limit: max_bytes}}}

      body_size > max_bytes ->
        {:error, {:body_too_large, %{bytes: body_size, limit: max_bytes}}}

      true ->
        :ok
    end
  end

  defp header_size(headers) do
    headers
    |> Enum.find_value(0, fn {key, value} ->
      if String.downcase(key) == "content-length" do
        case Integer.parse(value) do
          {int, _} -> int
          :error -> 0
        end
      end
    end)
  end

  defp request_headers(opts) do
    extra_headers = Keyword.get(opts, :headers, [])

    (extra_headers ++ @default_headers)
    |> Enum.uniq_by(fn {key, _} -> String.downcase(key) end)
  end

  defp request_options(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    recv_timeout = Keyword.get(opts, :recv_timeout, @default_recv_timeout)
    use_pool? = pool_enabled?(opts)

    {hackney_opts, pool_timeout} =
      if use_pool? do
        pool_name = opts |> Keyword.get(:hackney, []) |> Keyword.get(:pool, @hackney_pool)
        pool_ready? = ensure_pool(pool_name, opts)

        hackney_opts =
          opts
          |> Keyword.get(:hackney, [])
          |> Keyword.put_new(:pool, pool_name)

        if pool_ready? do
          timeout_override =
            opts
            |> Keyword.get(:pool_options, [])
            |> Keyword.get(:timeout)

          {hackney_opts, timeout_override}
        else
          {Keyword.delete(hackney_opts, :pool), nil}
        end
      else
        {Keyword.get(opts, :hackney, []), nil}
      end

    hackney_opts =
      hackney_opts
      |> Keyword.put_new(:timeout, pool_timeout || timeout)
      |> Keyword.put_new(:recv_timeout, recv_timeout)

    opts
    |> Keyword.take([])
    |> Keyword.put(:timeout, timeout)
    |> Keyword.put(:recv_timeout, recv_timeout)
    |> Keyword.put(:follow_redirect, false)
    |> Keyword.put(:hackney, hackney_opts)
  end

  defp success_status?(status), do: status in 200..299
  defp retriable_status?(status), do: status in 500..599

  defp retriable_error?(%HTTPoison.Error{reason: reason}), do: retriable_reason?(reason)
  defp retriable_error?(reason), do: retriable_reason?(reason)

  defp redirect_status?(status), do: status in [301, 302, 303, 307, 308]

  defp get_header(headers, name) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == String.downcase(name), do: value, else: nil
    end)
  end

  defp redirect_target(%Response{status_code: status, headers: headers}, current_url) do
    with location when is_binary(location) <- get_header(headers, "location"),
         {:ok, target} <- build_redirect_url(location, current_url),
         true <- allowed_redirect_host?(target.host) do
      {:ok, URI.to_string(target)}
    else
      nil ->
        {:error, {:http_redirect, status, nil}}

      {:error, reason} ->
        {:error, {:http_redirect, status, reason}}

      false ->
        location = get_header(headers, "location")
        {:error, {:http_redirect, status, location}}
    end
  end

  defp build_redirect_url(location, current_url) do
    current_uri = URI.parse(current_url)

    location_uri =
      case URI.parse(location) do
        %URI{scheme: nil} = uri ->
          URI.merge(current_uri, %{uri | scheme: current_uri.scheme})

        %URI{} = uri ->
          uri
      end

    case location_uri do
      %URI{scheme: scheme} = uri when scheme in ["http", "https"] ->
        {:ok, uri}

      _ ->
        {:error, location}
    end
  rescue
    ArgumentError ->
      {:error, location}
  end

  defp allowed_redirect_host?(host) when is_binary(host) do
    String.ends_with?(host, ".googleusercontent.com") or host == "docs.google.com"
  end

  defp allowed_redirect_host?(_), do: false

  defp pool_enabled?(opts) do
    config_enabled? =
      Application.get_env(:oli, :google_docs_import, [])
      |> Keyword.get(:use_pool, false)

    opt_enabled? = Keyword.get(opts, :use_pool)

    case opt_enabled? do
      nil -> config_enabled?
      value -> value
    end
  end

  defp ensure_pool(nil, _opts), do: false

  defp ensure_pool(pool_name, opts) do
    pool_config =
      @default_pool_options
      |> Keyword.merge(
        Application.get_env(:oli, :google_docs_import, [])
        |> Keyword.get(:pool_options, [])
      )
      |> Keyword.merge(Keyword.get(opts, :pool_options, []))

    case :hackney_pool.start_pool(pool_name, pool_config) do
      {:ok, _} ->
        true

      :ok ->
        true

      {:error, {:already_started, _}} ->
        true

      {:error, :already_started} ->
        true

      {:error, reason} ->
        Logger.warning(
          "Failed to start hackney pool #{inspect(pool_name)}: #{inspect(reason)}. Falling back to default pool."
        )

        false
    end
  rescue
    UndefinedFunctionError ->
      Logger.warning(
        "hackney_pool module unavailable; continuing without dedicated pool for Google Docs import."
      )

      false
  end

  defp retriable_reason?(reason) when reason in [:timeout, :connect_timeout, :closed], do: true
  defp retriable_reason?(_), do: false

  defp content_type(headers) do
    headers
    |> Enum.find_value(nil, fn {key, value} ->
      if String.downcase(key) == "content-type", do: value
    end)
  end

  defp backoff(attempt, opts) do
    base_delay = Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms)
    # simple jitter using attempt multiplier to avoid synchronized retries
    delay = base_delay * attempt
    if delay > 0, do: Process.sleep(delay)
  end

  defp redact_body(%Response{} = response), do: %Response{response | body: nil}

  defp redacted_reason(%HTTPoison.Error{} = error), do: %HTTPoison.Error{error | id: nil}
  defp redacted_reason(reason), do: reason
end
