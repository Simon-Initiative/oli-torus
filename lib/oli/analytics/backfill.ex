defmodule Oli.Analytics.Backfill do
  @moduledoc """
  Utilities for orchestrating ClickHouse bulk backfills from Torus.

  This context owns the lifecycle of `Oli.Analytics.Backfill.BackfillRun` records,
  including scheduling runs via Oban and updating their execution metadata as the
  associated worker progresses.
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.Inventory
  alias Oli.Analytics.Backfill.Notifier
  alias Oli.Analytics.Backfill.Worker
  alias Oli.Accounts.Author
  alias Oli.Repo

  require Logger

  @doc """
  Returns the fully qualified default target table for backfill operations.
  """
  @spec default_target_table() :: String.t()
  def default_target_table do
    analytics_module().raw_events_table()
  end

  @doc """
  List recorded backfill runs ordered from newest to oldest.
  """
  @spec list_runs(keyword()) :: [BackfillRun.t()]
  def list_runs(opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from run in BackfillRun,
        order_by: [desc: run.inserted_at],
        preload: [:initiated_by]

    query = if is_integer(limit) and limit > 0, do: from(run in query, limit: ^limit), else: query

    Repo.all(query)
  end

  @doc """
  Fetch a backfill run by id.
  """
  @spec get_run!(pos_integer()) :: BackfillRun.t()
  def get_run!(id) do
    Repo.get!(BackfillRun, id) |> Repo.preload(:initiated_by)
  end

  @doc """
  Returns a changeset for tracking modifications to a backfill run.
  """
  @spec change_backfill_run(BackfillRun.t(), map()) :: Ecto.Changeset.t()
  def change_backfill_run(%BackfillRun{} = run, attrs \\ %{}) do
    BackfillRun.creation_changeset(run, attrs)
  end

  @doc """
  Schedule a new ClickHouse backfill run.

  This function persists the run metadata and enqueues the corresponding Oban
  job in an atomic transaction. When `initiated_by` is provided, the originating
  author is recorded for auditing.
  """
  @spec schedule_backfill(map() | keyword(), Author.t()) ::
          {:ok, BackfillRun.t()} | {:error, term()}
  def schedule_backfill(attrs, %Author{} = initiated_by) do
    attrs =
      attrs
      |> normalize_attrs()
      |> maybe_apply_default_target_table()
      |> drop_server_fields()

    changeset =
      %BackfillRun{}
      |> BackfillRun.creation_changeset(attrs)
      |> Ecto.Changeset.put_change(:initiated_by_id, initiated_by.id)

    multi =
      Multi.new()
      |> Multi.insert(:run, changeset)
      |> Multi.run(:job, fn _repo, %{run: run} ->
        args = %{"run_id" => run.id}

        args
        |> Worker.new()
        |> Oban.insert()
      end)

    case Repo.transaction(multi) do
      {:ok, %{run: run}} ->
        _ = Notifier.broadcast(:manual_backfill)
        {:ok, Repo.preload(run, :initiated_by)}

      {:error, :run, changeset, _} ->
        {:error, changeset}

      {:error, :job, reason, %{run: run}} ->
        Repo.delete(run)
        {:error, reason}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  @doc """
  Update a backfill run using the base changeset.
  """
  @spec update_run(BackfillRun.t(), map()) ::
          {:ok, BackfillRun.t()} | {:error, Ecto.Changeset.t()}
  def update_run(%BackfillRun{} = run, attrs) do
    run
    |> BackfillRun.system_changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, _run} -> Notifier.broadcast(:manual_backfill)
      _ -> :ok
    end)
  end

  def refresh_running_runs do
    :ok = Inventory.recover_inflight_batches()

    from(run in BackfillRun, where: run.status in [:running, :pending])
    |> Repo.all()
    |> Enum.each(&refresh_run_status/1)

    :ok
  end

  @doc """
  Transition the provided run to the supplied status, merging any additional
  attributes. Timestamps are automatically managed when entering terminal
  states.
  """
  @spec transition_to(BackfillRun.t(), BackfillRun.status(), map()) ::
          {:ok, BackfillRun.t()} | {:error, Ecto.Changeset.t()}
  def transition_to(%BackfillRun{} = run, status, attrs \\ %{}) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:status, status)
      |> maybe_apply_status_timestamps(run, status)

    update_run(run, attrs)
  end

  @terminal_statuses [:completed, :failed, :cancelled]

  @doc """
  Ensure the run has an associated ClickHouse query identifier, generating and
  persisting one if necessary.
  """
  @spec ensure_query_id(BackfillRun.t()) :: {:ok, BackfillRun.t()} | {:error, term()}
  def ensure_query_id(%BackfillRun{query_id: query_id} = run) when is_binary(query_id) do
    {:ok, run}
  end

  def ensure_query_id(%BackfillRun{} = run) do
    query_id = generate_query_id(run)
    transition_to(run, run.status, %{query_id: query_id})
  end

  @doc """
  Permanently delete a backfill run that has finished.
  """
  @spec delete_run(BackfillRun.t()) :: {:ok, BackfillRun.t()} | {:error, term()}
  def delete_run(%BackfillRun{} = run) do
    if run.status in @terminal_statuses do
      Repo.delete(run)
      |> tap(fn
        {:ok, _run} -> Notifier.broadcast(:manual_backfill)
        _ -> :ok
      end)
    else
      {:error, :not_deletable}
    end
  end

  @doc """
  Generate a deterministic ClickHouse query identifier for a run.
  """
  @spec generate_query_id(BackfillRun.t()) :: String.t()
  def generate_query_id(%BackfillRun{id: id}) do
    "torus_backfill__run_#{id}_#{UUID.uuid4()}"
  end

  @doc """
  Retrieve AWS credentials for the S3 table function.
  """
  @spec aws_credentials() :: {:ok, map()} | {:error, String.t()}
  def aws_credentials do
    with {:ok, config} <- fetch_ex_aws_config() do
      case {config[:access_key_id], config[:secret_access_key]} do
        {nil, _} ->
          fallback_env_credentials()

        {_, nil} ->
          fallback_env_credentials()

        {access, secret} ->
          session = config[:security_token] || config[:session_token]

          {:ok,
           %{access_key_id: access, secret_access_key: secret}
           |> maybe_put_session_token(session)}
      end
    else
      {:error, _reason} -> fallback_env_credentials()
    end
  end

  defp fetch_ex_aws_config do
    {:ok, ExAws.Config.new(:s3)}
  rescue
    _ -> {:error, :ex_aws_config}
  end

  defp fallback_env_credentials do
    access_key =
      System.get_env("AWS_S3_ACCESS_KEY_ID") ||
        System.get_env("AWS_ACCESS_KEY_ID")

    secret_key =
      System.get_env("AWS_S3_SECRET_ACCESS_KEY") ||
        System.get_env("AWS_SECRET_ACCESS_KEY")

    session_token =
      System.get_env("AWS_S3_SESSION_TOKEN") ||
        System.get_env("AWS_SESSION_TOKEN")

    case {access_key, secret_key} do
      {nil, _} ->
        {:error, "Missing AWS access key. Configure AWS_S3_ACCESS_KEY_ID or AWS_ACCESS_KEY_ID."}

      {_, nil} ->
        {:error,
         "Missing AWS secret key. Configure AWS_S3_SECRET_ACCESS_KEY or AWS_SECRET_ACCESS_KEY."}

      {access, secret} ->
        {:ok,
         %{access_key_id: access, secret_access_key: secret}
         |> maybe_put_session_token(session_token)}
    end
  end

  defp maybe_put_session_token(creds, nil), do: Map.drop(creds, [:session_token])

  defp maybe_put_session_token(creds, token) do
    token =
      token
      |> to_string()
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

    case token do
      nil -> Map.drop(creds, [:session_token])
      value -> Map.put(creds, :session_token, value)
    end
  end

  defp maybe_apply_default_target_table(attrs) do
    case Map.get(attrs, :target_table) do
      nil -> Map.put(attrs, :target_table, default_target_table())
      "" -> Map.put(attrs, :target_table, default_target_table())
      target when is_binary(target) -> Map.put(attrs, :target_table, String.trim(target))
    end
  end

  defp drop_server_fields(attrs) when is_map(attrs),
    do: Map.drop(attrs, [:initiated_by_id, :status])

  defp drop_server_fields(attrs), do: attrs

  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(%{} = attrs), do: attrs
  defp normalize_attrs(_), do: %{}

  defp maybe_apply_status_timestamps(attrs, %BackfillRun{} = _run, status) do
    attrs =
      if status == :running do
        Map.put(attrs, :started_at, Map.get(attrs, :started_at) || DateTime.utc_now())
      else
        attrs
      end

    if status in [:completed, :failed, :cancelled] do
      Map.put(attrs, :finished_at, Map.get(attrs, :finished_at) || DateTime.utc_now())
    else
      attrs
    end
  end

  defp refresh_run_status(%BackfillRun{query_id: nil}), do: :ok

  defp refresh_run_status(%BackfillRun{} = run) do
    module = analytics_module()

    with {:ok, %{status: :running} = progress_info} <- module.query_progress(run.query_id) do
      progress_metadata =
        progress_info
        |> Map.put(:percent, compute_progress_percent(progress_info))
        |> stringify_keys()

      metadata =
        run.metadata
        |> merge_metadata(%{"progress" => progress_metadata})

      attrs =
        metrics_from_progress(progress_info)
        |> Map.put(:metadata, metadata)

      case update_run(run, attrs) do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          Logger.warning(
            "unable to update backfill run #{run.id} with progress: #{inspect(changeset.errors)}"
          )
      end
    end

    case module.query_status(run.query_id) do
      {:ok, %{status: :completed} = info} ->
        attrs = metrics_from_info(info)

        metadata =
          run.metadata
          |> merge_metadata(%{
            "query_id" => run.query_id,
            "query_status" => stringify_keys(info)
          })

        attrs = Map.put(attrs, :metadata, metadata)

        transition_to(run, :completed, attrs)

      {:ok, %{status: :failed} = info} ->
        metadata =
          run.metadata
          |> merge_metadata(%{
            "query_id" => run.query_id,
            "query_status" => stringify_keys(info)
          })

        error_message =
          info[:error] ||
            info[:exception] ||
            "Backfill query failed"

        transition_to(run, :failed, %{metadata: metadata, error: error_message})

      {:ok, _info} ->
        :ok

      {:error, reason} ->
        metadata =
          run.metadata
          |> merge_metadata(%{
            "query_id" => run.query_id,
            "query_status_error" => format_error(reason)
          })

        transition_to(run, run.status, %{metadata: metadata})
        :ok
    end
  end

  defp metrics_from_info(info) do
    %{}
    |> maybe_put_metric(:rows_read, info[:rows_read])
    |> maybe_put_metric(:rows_written, info[:rows_written])
    |> maybe_put_metric(:bytes_read, info[:bytes_read])
    |> maybe_put_metric(:bytes_written, info[:bytes_written])
    |> maybe_put_metric(:duration_ms, info[:query_duration_ms])
  end

  defp metrics_from_progress(progress) do
    %{}
    |> maybe_put_metric(:rows_read, progress[:read_rows])
    |> maybe_put_metric(:rows_written, progress[:written_rows])
    |> maybe_put_metric(:bytes_read, progress[:read_bytes])
    |> maybe_put_metric(:bytes_written, progress[:written_bytes])
    |> maybe_put_metric(:duration_ms, progress[:elapsed_ms])
  end

  defp maybe_put_metric(acc, _key, nil), do: acc

  defp maybe_put_metric(acc, :duration_ms, value) when is_float(value) do
    Map.put(acc, :duration_ms, trunc(value))
  end

  defp maybe_put_metric(acc, :duration_ms, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> Map.put(acc, :duration_ms, int)
      :error -> acc
    end
  end

  defp maybe_put_metric(acc, key, value), do: Map.put(acc, key, value)

  defp stringify_keys(info) when is_map(info) do
    info
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp merge_metadata(existing, additions) do
    existing = existing || %{}

    Enum.reduce(additions, existing, fn {key, value}, acc ->
      if is_nil(value) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp analytics_module do
    Application.get_env(:oli, :clickhouse_analytics_module, Oli.Analytics.ClickhouseAnalytics)
  end

  defp compute_progress_percent(progress) do
    total_rows = progress[:total_rows] || progress[:total_rows_approx]
    total_bytes = progress[:total_bytes] || progress[:total_bytes_approx]

    cond do
      is_number(total_rows) and total_rows > 0 and is_number(progress[:read_rows]) ->
        percent(progress[:read_rows] / total_rows)

      is_number(total_bytes) and total_bytes > 0 and is_number(progress[:read_bytes]) ->
        percent(progress[:read_bytes] / total_bytes)

      true ->
        nil
    end
  end

  defp percent(ratio) when ratio == :nan or ratio == :infinity, do: nil
  defp percent(ratio) when ratio < 0, do: 0.0
  defp percent(ratio) when ratio > 1, do: 100.0
  defp percent(ratio), do: ratio * 100.0
end
