defmodule Oli.Analytics.Backfill.Inventory.OrchestratorWorker do
  @moduledoc """
  Oban worker that reads an S3 inventory manifest and enqueues batch jobs for ClickHouse ingestion.
  """

  use Oban.Worker,
    queue: :clickhouse_inventory,
    max_attempts: 5,
    unique: [fields: [:args, :worker], keys: [:run_id], period: 600]

  require Logger

  alias Oli.Analytics.Backfill.Inventory
  alias Oli.Analytics.Backfill.InventoryRun

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) when is_integer(run_id) do
    run = Inventory.get_run!(run_id)

    case ensure_preparable(run) do
      {:discard, reason} ->
        Logger.info("Discarding inventory orchestrator for run #{run_id}: #{reason}")
        {:discard, reason}

      :ok ->
        execute(run)
    end
  end

  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    case parse_run_id(run_id) do
      {:ok, parsed_id} ->
        perform(%Oban.Job{args: %{"run_id" => parsed_id}})

      :error ->
        {:discard, "invalid run id"}
    end
  end

  defp execute(%InventoryRun{} = run) do
    with {:ok, run} <- Inventory.transition_run(run, :preparing, %{error: nil}),
         {:ok, manifest} <- fetch_manifest(run),
         files <- manifest_files(manifest),
         {:ok, batches} <- Inventory.prepare_batches(run, files),
         {:ok, run} <- annotate_run(run, manifest, length(files)),
         {:ok, run} <- Inventory.recompute_run_aggregates(run),
         :ok <- enqueue_batches(run, batches) do
      next_status = if Enum.empty?(batches), do: :completed, else: :running

      case Inventory.transition_run(run, next_status) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to transition run #{run.id} to #{next_status}: #{inspect(reason)}"
          )

          {:ok, run}
      end

      :ok
    else
      {:error, reason} ->
        Logger.error("Inventory orchestrator failed for run #{run.id}: #{format_error(reason)}")
        handle_failure(run, reason)

      {:discard, reason} ->
        Logger.info("Inventory orchestrator discarded for run #{run.id}: #{format_error(reason)}")
        {:discard, reason}
    end
  end

  defp ensure_preparable(%InventoryRun{status: status}) when status in [:pending, :failed],
    do: :ok

  defp ensure_preparable(%InventoryRun{status: status}) when status in [:completed, :cancelled],
    do: {:discard, "run already #{status}"}

  defp ensure_preparable(%InventoryRun{status: :running}), do: {:discard, "run already running"}
  defp ensure_preparable(_run), do: :ok

  defp fetch_manifest(%InventoryRun{} = run) do
    bucket = run.manifest_bucket

    with {:ok, key} <- manifest_key(run),
         {:ok, %{body: body}} <- request_manifest_object(bucket, key, run),
         {:ok, decoded} <- Jason.decode(body) do
      {:ok, decoded}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "invalid manifest json: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_manifest_object(bucket, key, %InventoryRun{} = run) do
    overrides = manifest_request_overrides(run)
    request = ExAws.S3.get_object(bucket, key)

    case overrides do
      [] -> ExAws.request(request)
      _ -> ExAws.request(request, overrides)
    end
  end

  defp manifest_files(%{"files" => files}) when is_list(files), do: files
  defp manifest_files(%{files: files}) when is_list(files), do: files
  defp manifest_files(_), do: []

  defp annotate_run(%InventoryRun{} = run, manifest, file_count) do
    metadata =
      run.metadata
      |> ensure_map()
      |> Map.put("manifest", merge_manifest_metadata(run, manifest, file_count))

    case Inventory.update_run(run, %{metadata: metadata}) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp merge_manifest_metadata(run, manifest, file_count) do
    manifest_meta = ensure_map(run.metadata)["manifest"] || %{}

    manifest_meta
    |> Map.put("file_count", file_count)
    |> Map.put("creation_timestamp", manifest_creation_time(manifest))
    |> Map.put("source_bucket", manifest["sourceBucket"] || manifest[:sourceBucket])
    |> Map.put(
      "destination_bucket",
      manifest["destinationBucket"] || manifest[:destinationBucket]
    )
  end

  defp manifest_creation_time(%{"creationTimestamp" => value}) when is_binary(value) do
    value
  end

  defp manifest_creation_time(%{"creationTimestamp" => value}) when is_number(value) do
    value
  end

  defp manifest_creation_time(%{creationTimestamp: value}) when is_number(value), do: value
  defp manifest_creation_time(%{creationTimestamp: value}) when is_binary(value), do: value
  defp manifest_creation_time(_), do: nil

  defp manifest_key(%InventoryRun{} = run) do
    manifest_meta = ensure_map(run.metadata)["manifest"] || %{}
    key = manifest_meta["key"] || manifest_meta[:key]

    cond do
      is_binary(key) ->
        {:ok, key}

      is_binary(run.inventory_prefix) ->
        {:ok, cleaned_join([run.inventory_prefix, "manifest.json"])}

      true ->
        {:error, "manifest key not available"}
    end
  end

  defp enqueue_batches(run, _batches) do
    case Inventory.maybe_enqueue_pending_batches(run) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_map(nil), do: %{}
  defp ensure_map(map) when is_map(map), do: map
  defp ensure_map(_), do: %{}

  defp manifest_request_overrides(%InventoryRun{} = run) do
    manifest_meta =
      run.metadata
      |> ensure_map()
      |> Map.get("manifest", %{})

    host = manifest_meta["host"] || manifest_meta[:host]
    scheme = manifest_meta["scheme"] || manifest_meta[:scheme]
    port = manifest_meta["port"] || manifest_meta[:port]
    manifest_credentials = configured_manifest_credentials()
    access_key_id = manifest_credentials.access_key_id
    secret_access_key = manifest_credentials.secret_access_key
    session_token = manifest_credentials.session_token

    []
    |> maybe_put_request_override(:host, normalize_host(host))
    |> maybe_put_request_override(:scheme, normalize_scheme(scheme))
    |> maybe_put_request_override(:port, normalize_port(port))
    |> maybe_put_request_override(:access_key_id, normalize_credential(access_key_id))
    |> maybe_put_request_override(
      :secret_access_key,
      normalize_credential(secret_access_key)
    )
    |> maybe_put_request_override(:security_token, normalize_credential(session_token))
  end

  defp configured_manifest_credentials do
    config = Application.get_env(:oli, :clickhouse_inventory, %{}) |> Enum.into(%{})

    %{
      access_key_id: config[:manifest_access_key_id],
      secret_access_key: config[:manifest_secret_access_key],
      session_token: config[:manifest_session_token]
    }
  end

  defp maybe_put_request_override(overrides, _key, nil), do: overrides
  defp maybe_put_request_override(overrides, key, value), do: Keyword.put(overrides, key, value)

  defp normalize_host(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_host(value) when is_atom(value), do: normalize_host(Atom.to_string(value))
  defp normalize_host(_), do: nil

  defp normalize_scheme(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        nil

      String.ends_with?(trimmed, "://") ->
        trimmed

      true ->
        trimmed <> "://"
    end
  end

  defp normalize_scheme(value) when is_atom(value), do: normalize_scheme(Atom.to_string(value))
  defp normalize_scheme(_), do: nil

  defp normalize_port(value) when is_integer(value) and value > 0, do: value

  defp normalize_port(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int > 0 -> int
      _ -> nil
    end
  end

  defp normalize_port(_), do: nil

  defp normalize_credential(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        nil

      trimmed ->
        case String.downcase(trimmed) do
          "nil" -> nil
          "null" -> nil
          "none" -> nil
          _ -> trimmed
        end
    end
  end

  defp normalize_credential(value) when is_atom(value),
    do: normalize_credential(Atom.to_string(value))

  defp normalize_credential(_), do: nil

  defp cleaned_join(parts) do
    parts
    |> Enum.map(&String.trim(to_string(&1), "/"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp parse_run_id(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_run_id(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_run_id(value) when is_float(value) do
    int_value = trunc(value)
    if int_value > 0, do: {:ok, int_value}, else: :error
  end

  defp parse_run_id(_), do: :error

  defp handle_failure(run, reason) do
    Inventory.transition_run(run, :failed, %{error: format_error(reason)})
    {:error, reason}
  end

  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
