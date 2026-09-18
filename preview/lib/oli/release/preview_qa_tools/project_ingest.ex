defmodule Oli.Release.PreviewQATools.ProjectIngest do
  @moduledoc """
  Downloads a bounded project archive and ingests it for an explicitly selected author.

  Destination reachability is intentionally governed by deployment network policy. This
  module validates the URL scheme, bounds local resource consumption, and never includes
  the source URL or archive contents in its results or logs.
  """

  import Ecto.Query, only: [from: 2]

  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Interop.Ingest
  alias Oli.Repo

  @default_max_bytes 100_000_000
  @default_connect_timeout 5_000
  @default_receive_timeout 30_000
  @default_max_redirects 5
  @default_max_entries 10_000
  @default_max_uncompressed_bytes 500_000_000
  @default_max_entry_bytes 100_000_000
  @default_max_compression_ratio 200
  @default_archive_validation_heap_bytes 256_000_000
  @default_archive_validation_timeout 30_000

  @doc "Downloads and ingests the project archive identified by `url`."
  def run(url, author_selector, opts \\ []) do
    with {:ok, parsed_url} <- validate_url(url),
         {:ok, author} <- resolve_author(author_selector),
         {:ok, project} <- with_archive(parsed_url, author, opts) do
      metadata = %{"source" => "url"}

      summary = %{
        project_id: project.id,
        project_slug: project.slug,
        project_title: project.title
      }

      {:ok, :project_ingest, summary, true, metadata}
    else
      {:error, code, message} -> {:error, code, message, false, %{"source" => "url"}}
      {:error, code, message, partial} -> {:error, code, message, partial, %{"source" => "url"}}
    end
  end

  defp validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url, "project URL must use HTTP or HTTPS"}
    end
  end

  defp resolve_author("default_admin") do
    configured_email = preview_config()[:default_admin_email]

    query =
      case configured_email do
        nil ->
          from(a in Author,
            where: a.system_role_id == ^SystemRole.role_id().system_admin and is_nil(a.locked_at)
          )

        email ->
          from(a in Author, where: a.email == ^email and is_nil(a.locked_at))
      end

    unique_author(query)
  end

  defp resolve_author("email:" <> email) when email != "" do
    unique_author(from(a in Author, where: a.email == ^email and is_nil(a.locked_at)))
  end

  defp resolve_author(_), do: {:error, :author_not_found, "author selector is invalid"}

  defp unique_author(query) do
    case Repo.all(from(a in query, limit: 2)) do
      [author] -> {:ok, author}
      [] -> {:error, :author_not_found, "author did not resolve to an active record"}
      _ -> {:error, :author_ambiguous, "author selector is ambiguous"}
    end
  end

  defp with_archive(uri, author, opts) do
    temp_root = Keyword.get(opts, :temp_root, System.tmp_dir!())

    suffix = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    directory = Path.join(temp_root, "preview-project-ingest-#{suffix}")

    case File.mkdir(directory) do
      :ok ->
        try do
          with :ok <- secure_directory(directory),
               archive_path <- Path.join(directory, "project.zip"),
               :ok <- download(uri, archive_path, opts),
               {:ok, project} <- ingest(archive_path, author, opts) do
            {:ok, project}
          end
        after
          File.rm_rf(directory)
        end

      {:error, _reason} ->
        {:error, :temporary_storage_failed, "temporary archive storage could not be created"}
    end
  end

  defp secure_directory(directory) do
    case File.chmod(directory, 0o700) do
      :ok ->
        :ok

      {:error, _reason} ->
        {:error, :temporary_storage_failed, "temporary archive storage could not be secured"}
    end
  end

  defp download(uri, archive_path, opts) do
    limits = Keyword.merge(preview_config(), opts)
    max_bytes = Keyword.get(limits, :project_ingest_max_bytes, @default_max_bytes)

    receive_timeout =
      Keyword.get(limits, :project_ingest_receive_timeout, @default_receive_timeout)

    request_fun = Keyword.get(opts, :request_fun, &request/2)

    with {:ok, file} <- open_private_file(archive_path) do
      try do
        case safe_request(request_fun, URI.to_string(uri), limits) do
          {:ok, response} ->
            try do
              deadline = System.monotonic_time(:millisecond) + receive_timeout
              receive_download(response, file, 0, max_bytes, deadline)
            after
              stop_response(response)
            end

          {:error, _reason} ->
            {:error, :download_failed, "project archive download failed"}
        end
      after
        File.close(file)
      end
    else
      {:error, _reason} -> {:error, :download_failed, "project archive download failed"}
    end
  end

  defp open_private_file(path) do
    case :file.open(String.to_charlist(path), [:write, :binary, :exclusive, {:mode, 0o600}]) do
      {:ok, file} ->
        case File.chmod(path, 0o600) do
          :ok ->
            {:ok, file}

          {:error, reason} ->
            File.close(file)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp safe_request(request_fun, url, limits) do
    request_fun.(url, limits)
  rescue
    _error -> {:error, :request_failed}
  catch
    _kind, _reason -> {:error, :request_failed}
  end

  defp request(url, opts) do
    # HTTPoison is a direct dependency and `async: :once` provides explicit per-chunk
    # backpressure and cancellation. Req is only transitive in this application.
    HTTPoison.get(url, [],
      stream_to: self(),
      async: :once,
      follow_redirect: true,
      max_redirect: Keyword.get(opts, :project_ingest_max_redirects, @default_max_redirects),
      timeout: Keyword.get(opts, :project_ingest_connect_timeout, @default_connect_timeout),
      recv_timeout: Keyword.get(opts, :project_ingest_receive_timeout, @default_receive_timeout)
    )
  end

  defp receive_download(%HTTPoison.AsyncResponse{id: id} = response, file, bytes, max, deadline) do
    HTTPoison.stream_next(response)
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: code} when code in 200..299 ->
        receive_download(response, file, bytes, max, deadline)

      %HTTPoison.AsyncStatus{id: ^id} ->
        {:error, :download_status, "project archive server returned a non-success status"}

      %HTTPoison.AsyncHeaders{id: ^id} ->
        receive_download(response, file, bytes, max, deadline)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} when bytes + byte_size(chunk) <= max ->
        case IO.binwrite(file, chunk) do
          :ok -> receive_download(response, file, bytes + byte_size(chunk), max, deadline)
          {:error, _reason} -> {:error, :download_failed, "project archive download failed"}
        end

      %HTTPoison.AsyncChunk{id: ^id} ->
        {:error, :download_too_large, "project archive exceeds the configured byte limit"}

      %HTTPoison.AsyncEnd{id: ^id} ->
        :ok

      %HTTPoison.Error{id: ^id} ->
        {:error, :download_failed, "project archive download failed"}
    after
      remaining -> {:error, :download_timeout, "project archive download timed out"}
    end
  end

  defp receive_download({:download, status, chunks}, file, _bytes, max, _timeout)
       when status in 200..299 and is_list(chunks) do
    Enum.reduce_while(chunks, {:ok, 0}, fn chunk, {:ok, bytes} ->
      case bytes + byte_size(chunk) do
        total when total <= max ->
          case IO.binwrite(file, chunk) do
            :ok ->
              {:cont, {:ok, total}}

            {:error, _reason} ->
              {:halt, {:error, :download_failed, "project archive download failed"}}
          end

        _total ->
          {:halt,
           {:error, :download_too_large, "project archive exceeds the configured byte limit"}}
      end
    end)
    |> case do
      {:ok, _bytes} -> :ok
      error -> error
    end
  end

  defp receive_download({:download, status, _chunks}, _file, _bytes, _max, _timeout)
       when is_integer(status) do
    {:error, :download_status, "project archive server returned a non-success status"}
  end

  defp receive_download({:download_error, :timeout}, _file, _bytes, _max, _timeout) do
    {:error, :download_timeout, "project archive download timed out"}
  end

  defp receive_download({:download_error, _reason}, _file, _bytes, _max, _timeout) do
    {:error, :download_failed, "project archive download failed"}
  end

  defp receive_download(_response, _file, _bytes, _max, _timeout) do
    {:error, :download_failed, "project archive download failed"}
  end

  defp stop_response(%HTTPoison.AsyncResponse{id: id}), do: :hackney.stop_async(id)
  defp stop_response(_response), do: :ok

  defp ingest(path, author, opts) do
    ingest_fun = Keyword.get(opts, :ingest_fun, &Ingest.ingest/2)

    with :ok <- validate_archive(path, opts) do
      safe_ingest(ingest_fun, path, author)
    end
  end

  defp safe_ingest(ingest_fun, path, author) do
    case ingest_fun.(path, author) do
      {:ok, project} -> {:ok, project}
      {:error, _reason} -> {:error, :ingest_failed, "project archive ingestion failed", true}
    end
  rescue
    _error -> {:error, :ingest_failed, "project archive ingestion failed", true}
  catch
    _kind, _reason -> {:error, :ingest_failed, "project archive ingestion failed", true}
  end

  defp validate_archive(path, opts) do
    limits = Keyword.merge(preview_config(), opts)
    parent = self()
    reference = make_ref()

    heap_bytes =
      Keyword.get(
        limits,
        :project_ingest_archive_validation_heap_bytes,
        @default_archive_validation_heap_bytes
      )

    heap_words = max(div(heap_bytes, :erlang.system_info(:wordsize)), 1)

    timeout =
      Keyword.get(
        limits,
        :project_ingest_archive_validation_timeout,
        @default_archive_validation_timeout
      )

    {pid, monitor} =
      :erlang.spawn_opt(
        fn -> send(parent, {reference, validate_archive_table(path, limits)}) end,
        [:monitor, {:max_heap_size, %{size: heap_words, kill: true, error_logger: false}}]
      )

    receive do
      {^reference, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^pid, _reason} ->
        {:error, :invalid_archive, "project archive failed safety validation", false}
    after
      timeout ->
        Process.exit(pid, :kill)
        Process.demonitor(monitor, [:flush])
        {:error, :invalid_archive, "project archive safety validation timed out", false}
    end
  end

  defp validate_archive_table(path, limits) do
    max_entries = Keyword.get(limits, :project_ingest_max_entries, @default_max_entries)

    with {:ok, table} <- :zip.table(String.to_charlist(path)),
         :ok <- validate_entries(table, max_entries, limits) do
      :ok
    else
      _ -> {:error, :invalid_archive, "project archive failed safety validation", false}
    end
  end

  defp validate_entries(entries, max_entries, limits) do
    max_total =
      Keyword.get(
        limits,
        :project_ingest_max_uncompressed_bytes,
        @default_max_uncompressed_bytes
      )

    max_entry =
      Keyword.get(limits, :project_ingest_max_entry_bytes, @default_max_entry_bytes)

    max_ratio =
      Keyword.get(limits, :project_ingest_max_compression_ratio, @default_max_compression_ratio)

    entries
    |> Enum.reduce_while({0, 0}, fn
      {:zip_file, _name, file_info, _comment, _offset, compressed}, {count, total} ->
        uncompressed = elem(file_info, 1)
        next_count = count + 1
        next_total = total + uncompressed
        ratio = uncompressed / max(compressed, 1)

        if next_count <= max_entries and uncompressed <= max_entry and next_total <= max_total and
             ratio <= max_ratio,
           do: {:cont, {next_count, next_total}},
           else: {:halt, :error}

      _entry, state ->
        {:cont, state}
    end)
    |> case do
      :error -> :error
      {_count, _total} -> :ok
    end
  end

  defp preview_config, do: Application.get_env(:oli, :preview_qa_tools, [])
end
