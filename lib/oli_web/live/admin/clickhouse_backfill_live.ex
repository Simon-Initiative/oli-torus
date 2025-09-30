defmodule OliWeb.Admin.ClickhouseBackfillLive do
  @moduledoc """
  Admin console for orchestrating bulk ClickHouse backfill jobs.
  """

  use OliWeb, :live_view

  import Ecto.Changeset, only: [add_error: 3]

  alias Jason
  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @runs_limit 25
  @auto_refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    default_inputs = default_form_inputs()

    changeset =
      %BackfillRun{}
      |> BackfillRun.changeset(%{
        target_table: Backfill.default_target_table(),
        format: "JSONAsString"
      })

    socket =
      assign(socket,
        title: "ClickHouse Bulk Backfill",
        breadcrumb: breadcrumb(),
        runs: Backfill.list_runs(limit: @runs_limit),
        changeset: changeset,
        form_inputs: default_inputs,
        form: to_form(changeset, as: :backfill)
      )
      |> maybe_schedule_refresh()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"backfill" => params}, socket) do
    case normalize_form_params(params) do
      {:ok, attrs, raw_inputs} ->
        changeset =
          %BackfillRun{}
          |> BackfillRun.creation_changeset(attrs)
          |> Map.put(:action, :validate)

        {:noreply,
         assign(socket,
           changeset: changeset,
           form_inputs: raw_inputs,
           form: to_form(changeset, as: :backfill)
         )}

      {:error, field, message, attrs, raw_inputs} ->
        changeset =
          %BackfillRun{}
          |> BackfillRun.creation_changeset(attrs)
          |> add_error(field, message)
          |> Map.put(:action, :validate)

        {:noreply,
         assign(socket,
           changeset: changeset,
           form_inputs: raw_inputs,
           form: to_form(changeset, as: :backfill)
         )}
    end
  end

  @impl true
  def handle_event("schedule", %{"backfill" => params}, socket) do
    case normalize_form_params(params) do
      {:ok, attrs, _raw_inputs} ->
        case Backfill.schedule_backfill(attrs, socket.assigns[:current_author]) do
          {:ok, _run} ->
            {:noreply,
             socket
             |> put_flash(:info, "Backfill job has been enqueued.")
             |> assign(
               runs: Backfill.list_runs(limit: @runs_limit),
               changeset: reset_changeset(),
               form_inputs: default_form_inputs(),
               form: to_form(reset_changeset(), as: :backfill)
             )
             |> maybe_schedule_refresh()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             assign(socket,
               changeset: Map.put(changeset, :action, :insert),
               form_inputs: refill_inputs(params),
               form: to_form(Map.put(changeset, :action, :insert), as: :backfill)
             )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> assign(
           changeset: reset_changeset(),
           form_inputs: refill_inputs(params),
           form: to_form(reset_changeset(), as: :backfill)
         )
         |> maybe_schedule_refresh()}
        end

      {:error, field, message, attrs, raw_inputs} ->
        changeset =
          %BackfillRun{}
          |> BackfillRun.creation_changeset(attrs)
          |> add_error(field, message)
          |> Map.put(:action, :insert)

        {:noreply,
         assign(socket,
           changeset: changeset,
           form_inputs: raw_inputs,
           form: to_form(changeset, as: :backfill)
         )}
    end
  end

  @impl true
  def handle_event("refresh_runs", _params, socket) do
    {:noreply, socket |> refresh_runs() |> maybe_schedule_refresh()}
  end

  @impl true
  def handle_info(:refresh_runs, socket) do
    socket = refresh_runs(socket)

    socket =
      if running_job?(socket.assigns.runs) do
        schedule_refresh(socket)
      else
        assign(socket, refresh_timer?: false)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full p-6 space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold">ClickHouse Bulk Backfill</h1>
          <p class="text-sm text-gray-600 dark:text-gray-300 mt-1">
            Launch and monitor long running ingest jobs that pull historical xAPI events directly from S3 into ClickHouse.
          </p>
        </div>
        <div>
          <.link navigate={~p"/admin/clickhouse"} class="text-sm text-delivery-primary hover:underline">
            View ClickHouse Analytics →
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div class="xl:col-span-1">
          <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-5 space-y-4">
            <div>
              <h2 class="text-xl font-semibold">Schedule Backfill</h2>
              <p class="text-sm text-gray-600 dark:text-gray-300">
                Provide an S3 pattern that matches the historical JSONL exports. For safety, start with a dry run to validate scope.
              </p>
            </div>

            <.form
              for={@form}
              phx-change="validate"
              phx-submit="schedule"
              class="space-y-4"
            >
              <.input
                field={@form[:s3_pattern]}
                label="S3 Pattern"
                placeholder="s3://bucket/path/**/*.jsonl"
                value={@form_inputs.s3_pattern}
                required
              />

              <.input
                field={@form[:target_table]}
                label="Target Table"
                value={@form_inputs.target_table}
              />

              <.input
                field={@form[:format]}
                type="select"
                label="Source Format"
                options={["JSONAsString", "JSONEachRow"]}
                value={@form_inputs.format}
              />

              <label class="flex items-center space-x-2 text-sm font-medium text-gray-700 dark:text-gray-300">
                <input
                  type="checkbox"
                  name="backfill[dry_run]"
                  value="true"
                  checked={truthy?(@form_inputs.dry_run)}
                  class="h-4 w-4 rounded border-gray-300 text-delivery-primary focus:ring-delivery-primary"
                />
                <span>Dry run (count rows only)</span>
              </label>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  ClickHouse Settings (JSON object)
                </label>
                <textarea
                  name="backfill[clickhouse_settings]"
                  rows="4"
                  class="w-full mt-1 rounded-md border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm font-mono p-2"
                  placeholder='{"max_download_threads": 8}'
                >{@form_inputs.clickhouse_settings}</textarea>
                <%= for {msg, _opts} <- Keyword.get(@changeset.errors, :clickhouse_settings, []) do %>
                  <p class="mt-1 text-sm text-red-600">{msg}</p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Query Parameters (JSON object)
                </label>
                <textarea
                  name="backfill[options]"
                  rows="3"
                  class="w-full mt-1 rounded-md border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm font-mono p-2"
                  placeholder='{"max_threads": 4}'
                >{@form_inputs.options}</textarea>
                <%= for {msg, _opts} <- Keyword.get(@changeset.errors, :options, []) do %>
                  <p class="mt-1 text-sm text-red-600">{msg}</p>
                <% end %>
              </div>

              <div class="flex items-center justify-end space-x-3 pt-2">
                <.button type="button" phx-click="refresh_runs" class="btn-secondary">
                  Refresh Jobs
                </.button>
                <.button type="submit" class="btn-primary">
                  Enqueue Backfill
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div class="xl:col-span-2">
          <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-5">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h2 class="text-xl font-semibold">Recent Runs</h2>
                <p class="text-sm text-gray-600 dark:text-gray-300">Showing the {length(@runs)} most recent jobs.</p>
              </div>
              <.button phx-click="refresh_runs" class="btn-secondary btn-sm">
                Refresh
              </.button>
            </div>

            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700 text-sm">
                <thead class="bg-gray-50 dark:bg-gray-800">
                  <tr>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">Run</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">Status</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">S3 Pattern</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">Metrics</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">Timeline</th>
                    <th class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300">Details</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                  <%= for run <- @runs do %>
                    <tr class="align-top">
                      <td class="px-3 py-3 space-y-1">
                        <div class="font-semibold">Run #{run.id}</div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">Table: {run.target_table}</div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">Format: {run.format}</div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">Dry run: {if run.dry_run, do: "Yes", else: "No"}</div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">
                          Initiator: {format_initiator(run.initiated_by)}
                        </div>
                      </td>
                      <td class="px-3 py-3">
                        <span class={status_badge_classes(run.status)}>{Phoenix.Naming.humanize(run.status)}</span>
                        <%= if run.query_id do %>
                          <div class="mt-2 text-xs text-gray-500 break-all">Query ID: {run.query_id}</div>
                        <% end %>
                        <% progress_value = progress_percent(run) %>
                        <% progress_text = progress_label(run) %>
                        <div :if={progress_value} class="mt-2">
                          <div class="h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                            <div
                              class="h-2 bg-blue-500 transition-all"
                              style={"width: #{Float.round(progress_value, 1)}%"}
                            ></div>
                          </div>
                        </div>
                        <p :if={progress_text} class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                          {progress_text}
                        </p>
                        <%= if run.error do %>
                          <div class="mt-2 text-xs text-red-600 break-words">{run.error}</div>
                        <% end %>
                      </td>
                      <td class="px-3 py-3 max-w-xs">
                        <div class="text-xs text-gray-700 dark:text-gray-300 break-all">
                          {run.s3_pattern}
                        </div>
                      </td>
                      <td class="px-3 py-3 text-xs text-gray-600 dark:text-gray-300 space-y-1">
                        <div>Rows read: {format_int(run.rows_read)}</div>
                        <div>Rows written: {format_int(run.rows_written)}</div>
                        <div>Bytes read: {format_int(run.bytes_read)}</div>
                        <div>Bytes written: {format_int(run.bytes_written)}</div>
                        <div>Duration (ms): {format_int(run.duration_ms)}</div>
                      </td>
                      <td class="px-3 py-3 text-xs text-gray-600 dark:text-gray-300 space-y-1">
                        <div>Inserted: {format_timestamp(run.inserted_at)}</div>
                        <div>Started: {format_timestamp(run.started_at)}</div>
                        <div>Finished: {format_timestamp(run.finished_at)}</div>
                      </td>
                      <td class="px-3 py-3 text-xs text-gray-600 dark:text-gray-300">
                        <details>
                          <summary class="cursor-pointer text-delivery-primary">Metadata</summary>
                          <pre class="mt-2 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-2 max-h-48 overflow-y-auto">{encode_metadata(run.metadata)}</pre>
                        </details>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@runs) do %>
                <div class="py-8 text-center text-sm text-gray-500">No backfill jobs recorded yet.</div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp breadcrumb do
    [
      Breadcrumb.new(%{full_title: "Admin", link: ~p"/admin"}),
      Breadcrumb.new(%{full_title: "ClickHouse Bulk Backfill"})
    ]
  end

  defp normalize_form_params(params) do
    params = Map.new(params || %{})
    original_pattern = params |> Map.get("s3_pattern", "") |> String.trim()

    with {:ok, s3_pattern} <- normalize_s3_pattern(original_pattern) do
      target_table = params |> Map.get("target_table", Backfill.default_target_table()) |> String.trim()
      format = params |> Map.get("format", "JSONAsString") |> String.trim()
      dry_run = truthy?(Map.get(params, "dry_run"))
      settings_raw = params |> Map.get("clickhouse_settings", "") |> String.trim()
      options_raw = params |> Map.get("options", "") |> String.trim()

      settings_result = parse_json_field(settings_raw, :clickhouse_settings)
      options_result = parse_json_field(options_raw, :options)

      case {settings_result, options_result} do
        {{:ok, settings_map}, {:ok, options_map}} ->
          attrs = %{
            target_table: target_table,
            s3_pattern: s3_pattern,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_map,
            options: options_map
          }

          raw_inputs = %{
            s3_pattern: s3_pattern,
            target_table: target_table,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_raw,
            options: options_raw
          }

          {:ok, attrs, raw_inputs}

        {{:error, {field, message}}, {:ok, options_map}} ->
          attrs = %{
            target_table: target_table,
            s3_pattern: s3_pattern,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: %{},
            options: options_map
          }

          raw_inputs = %{
            s3_pattern: s3_pattern,
            target_table: target_table,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_raw,
            options: options_raw
          }

          {:error, field, message, attrs, raw_inputs}

        {{:ok, settings_map}, {:error, {field, message}}} ->
          attrs = %{
            target_table: target_table,
            s3_pattern: s3_pattern,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_map,
            options: %{}
          }

          raw_inputs = %{
            s3_pattern: s3_pattern,
            target_table: target_table,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_raw,
            options: options_raw
          }

          {:error, field, message, attrs, raw_inputs}

        {{:error, {field, message}}, {:error, _other}} ->
          attrs = %{
            target_table: target_table,
            s3_pattern: s3_pattern,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: %{},
            options: %{}
          }

          raw_inputs = %{
            s3_pattern: s3_pattern,
            target_table: target_table,
            format: format,
            dry_run: dry_run,
            clickhouse_settings: settings_raw,
            options: options_raw
          }

          {:error, field, message, attrs, raw_inputs}
      end
    else
      {:error, message} ->
        raw_inputs = default_form_inputs() |> Map.put(:s3_pattern, original_pattern)
        {:error, :s3_pattern, message, %{}, raw_inputs}
    end
  end

  defp parse_json_field("", _field), do: {:ok, %{}}
  defp parse_json_field(value, field) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _other} -> {:error, {field, "must be a JSON object"}}
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {field, "invalid JSON: #{Exception.message(error)}"}}
    end
  end

  defp truthy?(value) when value in [true, "true", "1", 1, "on", "yes"], do: true
  defp truthy?(_), do: false

  defp normalize_s3_pattern(pattern) when is_binary(pattern) do
    trimmed = String.trim(pattern || "")

    cond do
      trimmed == "" -> {:ok, ""}
      String.starts_with?(trimmed, ["s3://", "S3://"]) ->
        pattern_rest =
          trimmed
          |> String.replace_prefix("S3://", "s3://")
          |> String.replace_prefix("s3://", "")

        {bucket, prefix} =
          case String.split(pattern_rest, "/", parts: 2) do
            [head | tail] -> {head, List.first(tail) || ""}
            [] -> {"", ""}
          end

        if String.contains?(bucket, "amazonaws.com") do
          case bucket |> String.split(".s3", parts: 2) |> List.first() do
            nil -> {:error, "unable to determine S3 bucket"}
            "" -> {:error, "missing S3 bucket in URL"}
            actual_bucket -> {:ok, "s3://#{actual_bucket}/#{prefix}"}
          end
        else
          {:ok, "s3://" <> pattern_rest}
        end
      true ->
        trimmed
        |> URI.parse()
        |> extract_bucket_and_prefix()
        |> case do
          {:ok, bucket, key} -> {:ok, "s3://#{bucket}/#{key}"}
          :pass -> {:ok, trimmed}
          {:error, message} -> {:error, message}
        end
    end
  end

  defp normalize_s3_pattern(_), do: {:error, "invalid S3 pattern"}

  defp extract_bucket_and_prefix(%URI{scheme: scheme, host: host, path: path})
       when scheme in ["http", "https"] do
    cond do
      host in ["s3.amazonaws.com", "s3.us-east-1.amazonaws.com"] ->
        path
        |> String.trim_leading("/")
        |> split_bucket_and_prefix()

      String.contains?(host || "", ".s3") ->
        bucket = host |> String.split(".s3", parts: 2) |> List.first()
        prefix = String.trim_leading(path || "", "/")
        if bucket in [nil, ""] do
          {:error, "unable to determine S3 bucket"}
        else
          {:ok, bucket, prefix}
        end

      true ->
        :pass
    end
  end

  defp extract_bucket_and_prefix(%URI{}), do: :pass

  defp split_bucket_and_prefix(""), do: {:error, "missing S3 bucket in URL"}

  defp split_bucket_and_prefix(path) do
    case String.split(path, "/", parts: 2) do
      [bucket, rest] when bucket != "" and rest != "" -> {:ok, bucket, rest}
      [bucket] when bucket != "" -> {:ok, bucket, ""}
      _ -> {:error, "missing S3 bucket in URL"}
    end
  end

  defp refresh_runs(socket) do
    Backfill.refresh_running_runs()
    assign(socket, runs: Backfill.list_runs(limit: @runs_limit))
  end

  defp running_job?(runs) do
    Enum.any?(runs, &(&1.status in [:pending, :running]))
  end

  defp maybe_schedule_refresh(socket) do
    if running_job?(socket.assigns.runs) do
      schedule_refresh(socket)
    else
      socket
    end
  end

  defp schedule_refresh(socket) do
    unless socket.assigns[:refresh_timer?] do
      Process.send_after(self(), :refresh_runs, @auto_refresh_interval)
    end

    assign(socket, refresh_timer?: true)
  end

  defp reset_changeset do
    %BackfillRun{}
    |> BackfillRun.changeset(%{
      target_table: Backfill.default_target_table(),
      format: "JSONAsString",
      dry_run: true
    })
  end

  defp default_form_inputs do
    %{
      s3_pattern: "",
      target_table: Backfill.default_target_table(),
      format: "JSONAsString",
      dry_run: true,
      clickhouse_settings: "",
      options: ""
    }
  end

  defp refill_inputs(params) do
    params = Map.new(params || %{})

    %{
      s3_pattern: Map.get(params, "s3_pattern", "") |> String.trim(),
      target_table: Map.get(params, "target_table", Backfill.default_target_table()) |> String.trim(),
      format: Map.get(params, "format", "JSONAsString") |> String.trim(),
      dry_run: truthy?(Map.get(params, "dry_run")),
      clickhouse_settings: Map.get(params, "clickhouse_settings", "") |> String.trim(),
      options: Map.get(params, "options", "") |> String.trim()
    }
  end

  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp status_badge_classes(:completed),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-green-100 text-green-800"

  defp status_badge_classes(:running),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-blue-100 text-blue-800"

  defp status_badge_classes(:failed),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-red-100 text-red-800"

  defp status_badge_classes(:cancelled),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-yellow-100 text-yellow-800"

  defp status_badge_classes(_),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-gray-100 text-gray-800"

  defp format_int(nil), do: "—"
  defp format_int(value) when is_integer(value), do: Integer.to_string(value)
  defp format_int(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp format_int(_), do: "—"

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(%NaiveDateTime{} = dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_timestamp()
  rescue
    _ -> NaiveDateTime.to_string(dt)
  end

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end

  defp encode_metadata(nil), do: "{}"

  defp encode_metadata(map) when map == %{}, do: "{}"

  defp encode_metadata(map) when is_map(map) do
    Jason.encode!(map, pretty: true)
  rescue
    _ -> inspect(map)
  end

  defp encode_metadata(other), do: inspect(other)

  defp format_initiator(nil), do: "Unknown"
  defp format_initiator(%{name: name}) when is_binary(name) and name != "", do: name
  defp format_initiator(%{email: email}) when is_binary(email), do: email
  defp format_initiator(_), do: "Unknown"

  defp progress_metadata(%BackfillRun{metadata: metadata}) when is_map(metadata) do
    cond do
      Map.has_key?(metadata, "progress") -> metadata["progress"]
      Map.has_key?(metadata, :progress) -> metadata[:progress]
      true -> %{}
    end
  end

  defp progress_metadata(_), do: %{}

  defp progress_percent(run) do
    progress_metadata(run)
    |> fetch_progress_value(["percent", :percent])
    |> case do
      value when is_number(value) ->
        value
        |> max(0.0)
        |> min(100.0)

      _ -> nil
    end
  end

  defp progress_label(run) do
    metadata = progress_metadata(run)
    read_rows = fetch_progress_value(metadata, ["read_rows", :read_rows])
    total_rows =
      fetch_progress_value(metadata, ["total_rows", :total_rows]) ||
        fetch_progress_value(metadata, ["total_rows_approx", :total_rows_approx])

    read_bytes = fetch_progress_value(metadata, ["read_bytes", :read_bytes])
    total_bytes =
      fetch_progress_value(metadata, ["total_bytes", :total_bytes]) ||
        fetch_progress_value(metadata, ["total_bytes_approx", :total_bytes_approx])

    cond do
      is_integer(read_rows) and is_integer(total_rows) and total_rows > 0 ->
        percent = progress_percent(run)
        label_percent = if percent, do: " (#{format_percent(percent)}%)", else: ""
        "Rows: #{format_int(read_rows)} / #{format_int(total_rows)}#{label_percent}"

      is_integer(read_rows) ->
        "Rows read: #{format_int(read_rows)}"

      is_integer(read_bytes) and is_integer(total_bytes) and total_bytes > 0 ->
        percent = progress_percent(run)
        label_percent = if percent, do: " (#{format_percent(percent)}%)", else: ""
        "Bytes: #{format_int(read_bytes)} / #{format_int(total_bytes)}#{label_percent}"

      is_integer(read_bytes) ->
        "Bytes read: #{format_int(read_bytes)}"

      true ->
        nil
    end
  end

  defp format_percent(percent) when is_number(percent) do
    :erlang.float_to_binary(percent, decimals: 1)
  end

  defp format_percent(_), do: nil

  defp fetch_progress_value(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key -> map[key] end)
  end

  defp fetch_progress_value(_map, _keys), do: nil
end
