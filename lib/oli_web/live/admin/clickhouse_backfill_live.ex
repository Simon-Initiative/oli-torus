defmodule OliWeb.Admin.ClickhouseBackfillLive do
  @moduledoc """
  Admin console for orchestrating bulk ClickHouse backfill jobs.
  """

  use OliWeb, :live_view

  import Ecto.Changeset, only: [add_error: 3]

  alias Jason
  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.Inventory
  alias Oli.Analytics.Backfill.InventoryBatch
  alias Oli.Analytics.Backfill.InventoryRun
  alias Oli.Analytics.Backfill.Notifier
  alias Oli.Features
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @runs_limit 25
  @inventory_runs_limit 25

  @impl true
  def mount(params, _session, socket) do
    if Features.enabled?("clickhouse-olap") and Features.enabled?("clickhouse-olap-bulk-ingest") do
      default_inputs = default_form_inputs()

      changeset =
        %BackfillRun{}
        |> BackfillRun.changeset(%{
          target_table: Backfill.default_target_table(),
          format: "JSONAsString"
        })

      inventory_config = Application.get_env(:oli, :clickhouse_inventory, []) |> Enum.into(%{})
      inventory_defaults = inventory_default_inputs(inventory_config)
      inventory_changeset = inventory_form_changeset(inventory_defaults, inventory_config)
      inventory_form = to_form(inventory_changeset, as: :inventory)
      inventory_form_inputs = inventory_form_values(inventory_defaults, inventory_config)

      active_tab = resolve_active_tab(params)

      user_token =
        case Map.get(socket.assigns, :current_author) do
          %{id: author_id} ->
            Phoenix.Token.sign(OliWeb.Endpoint, "user socket", author_id)

          _ ->
            nil
        end

      socket =
        assign(socket,
          title: "ClickHouse Backfills",
          breadcrumbs: breadcrumbs(),
          runs: Backfill.list_runs(limit: @runs_limit),
          inventory_runs: Inventory.list_runs(limit: @inventory_runs_limit),
          changeset: changeset,
          form_inputs: default_inputs,
          form: to_form(changeset, as: :backfill),
          inventory_form: inventory_form,
          inventory_form_inputs: inventory_form_inputs,
          inventory_config: inventory_config,
          inventory_advanced_touched?: false,
          active_tab: active_tab,
          user_token: user_token
        )

      if connected?(socket) do
        Notifier.subscribe()
      end

      {:ok, socket}
    else
      message =
        cond do
          not Features.enabled?("clickhouse-olap") ->
            "ClickHouse analytics are not enabled."

          not Features.enabled?("clickhouse-olap-bulk-ingest") ->
            "ClickHouse bulk ingest is not enabled."

          true ->
            "ClickHouse bulk ingest is not enabled."
        end

      {:ok,
       socket
       |> put_flash(:error, message)
       |> redirect(to: ~p"/admin")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, active_tab: resolve_active_tab(params))}
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
             )}

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
             )}
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

  def handle_event("delete_backfill_run", %{"id" => id}, socket) do
    with {run_id, _} <- Integer.parse(to_string(id)),
         run <- Backfill.get_run!(run_id),
         {:ok, _} <- Backfill.delete_run(run) do
      {:noreply,
       socket
       |> put_flash(:info, "Run #{run_id} deleted.")
       |> refresh_runs()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid run identifier")}

      {:error, :not_deletable} ->
        {:noreply,
         socket
         |> put_flash(:error, "Run #{id} is still processing.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Run not found")}
  end

  def handle_event("pause_inventory_run", %{"id" => id}, socket) do
    with {run_id, _} <- Integer.parse(to_string(id)),
         run <- Inventory.get_run!(run_id),
         {:ok, _run} <- Inventory.pause_run(run) do
      socket =
        socket
        |> put_flash(:info, "Run #{run_id} paused.")
        |> refresh_runs()

      {:noreply, socket}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid run identifier")}

      {:error, :not_pausable} ->
        {:noreply, put_flash(socket, :info, "Run #{id} cannot be paused.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> refresh_runs()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Run not found")}
  end

  def handle_event("resume_inventory_run", %{"id" => id}, socket) do
    with {run_id, _} <- Integer.parse(to_string(id)),
         run <- Inventory.get_run!(run_id),
         {:ok, _run} <- Inventory.resume_run(run) do
      socket =
        socket
        |> put_flash(:info, "Run #{run_id} resumed.")
        |> refresh_runs()

      {:noreply, socket}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid run identifier")}

      {:error, :not_paused} ->
        {:noreply, put_flash(socket, :info, "Run #{id} is not paused.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> refresh_runs()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Run not found")}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    target = resolve_active_tab(%{"active_tab" => tab})

    {:noreply, push_patch(socket, to: active_tab_path(socket, target))}
  end

  def handle_event("inventory_validate", %{"inventory" => params}, socket) do
    changeset =
      params
      |> inventory_form_changeset(socket.assigns.inventory_config)
      |> Map.put(:action, :validate)

    form_inputs =
      if changeset.valid? do
        changeset
        |> Ecto.Changeset.apply_changes()
        |> inventory_form_values(socket.assigns.inventory_config)
      else
        inventory_inputs_from_params(params, socket.assigns.inventory_config)
      end

    {:noreply,
     assign(socket,
       inventory_form: to_form(changeset, as: :inventory),
       inventory_form_inputs: form_inputs,
       inventory_advanced_touched?: true
     )}
  end

  def handle_event("inventory_validate", _params, socket), do: {:noreply, socket}

  def handle_event("inventory_schedule", %{"inventory" => params}, socket) do
    changeset = inventory_form_changeset(params, socket.assigns.inventory_config)

    if changeset.valid? do
      attrs =
        changeset
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:format, "JSONAsString")
        |> Map.update(:dry_run, false, &truthy?/1)

      case Inventory.schedule_run(attrs, socket.assigns[:current_author]) do
        {:ok, _run} ->
          defaults = inventory_default_inputs(socket.assigns.inventory_config)

          socket =
            socket
            |> refresh_runs()
            |> assign(
              inventory_form:
                to_form(inventory_form_changeset(defaults, socket.assigns.inventory_config),
                  as: :inventory
                ),
              inventory_form_inputs:
                inventory_form_values(defaults, socket.assigns.inventory_config),
              inventory_advanced_touched?: false,
              active_tab: :inventory
            )
            |> put_flash(:info, "Inventory batch run has been enqueued.")

          {:noreply, socket}

        {:error, %Ecto.Changeset{} = error_changeset} ->
          error_changeset = Map.put(error_changeset, :action, :insert)

          {:noreply,
           assign(socket,
             inventory_form: to_form(error_changeset, as: :inventory),
             inventory_form_inputs:
               inventory_inputs_from_params(params, socket.assigns.inventory_config),
             inventory_advanced_touched?: true
           )}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, format_error(reason))
           |> assign(
             inventory_form: to_form(Map.put(changeset, :action, :insert), as: :inventory),
             inventory_form_inputs:
               inventory_inputs_from_params(params, socket.assigns.inventory_config),
             inventory_advanced_touched?: true
           )}
      end
    else
      changeset = Map.put(changeset, :action, :validate)

      {:noreply,
       assign(socket,
         inventory_form: to_form(changeset, as: :inventory),
         inventory_form_inputs:
           inventory_inputs_from_params(params, socket.assigns.inventory_config),
         inventory_advanced_touched?: true
       )}
    end
  end

  def handle_event("cancel_inventory_run", %{"id" => id}, socket) do
    with {run_id, _} <- Integer.parse(to_string(id)),
         run <- Inventory.get_run!(run_id),
         {:ok, _run} <- Inventory.cancel_run(run) do
      socket =
        socket
        |> put_flash(:info, "Run #{run_id} cancellation requested.")
        |> refresh_runs()

      {:noreply, socket}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid run identifier")}

      {:error, :not_cancellable} ->
        {:noreply, put_flash(socket, :info, "Run #{id} is already finished.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> refresh_runs()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Run not found")}
  end

  def handle_event("delete_inventory_run", %{"id" => id}, socket) do
    with {run_id, _} <- Integer.parse(to_string(id)),
         run <- Inventory.get_run!(run_id),
         {:ok, _} <- Inventory.delete_run(run) do
      {:noreply,
       socket
       |> put_flash(:info, "Inventory run #{run_id} deleted.")
       |> refresh_runs()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid run identifier")}

      {:error, :not_deletable} ->
        {:noreply,
         socket
         |> put_flash(:error, "Run #{id} is still processing.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> refresh_runs()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Run not found")}
  end

  def handle_event("retry_inventory_batch", %{"id" => id}, socket) do
    with {batch_id, _} <- Integer.parse(to_string(id)),
         batch <- Inventory.get_batch!(batch_id),
         {:ok, _batch} <- Inventory.retry_batch(batch) do
      socket =
        socket
        |> put_flash(:info, "Batch #{batch_id} retry queued.")
        |> refresh_runs()

      {:noreply, socket}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Invalid batch identifier")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(reason))
         |> refresh_runs()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Batch not found")}
  end

  @impl true
  def handle_info(
        {:clickhouse_backfill_updated, %{source: :inventory_batch, metadata: metadata}},
        socket
      ) do
    run_id = metadata_id(metadata, :run_id)

    socket =
      case run_id do
        nil -> refresh_runs(socket)
        id -> update_inventory_run_assign(socket, id)
      end

    {:noreply, socket}
  end

  def handle_info(
        {:clickhouse_backfill_updated, %{source: :inventory_run, metadata: metadata}},
        socket
      ) do
    run_id = metadata_id(metadata, :run_id)

    socket =
      case run_id do
        nil -> refresh_runs(socket)
        id -> update_inventory_run_assign(socket, id)
      end

    {:noreply, socket}
  end

  def handle_info({:clickhouse_backfill_updated, _payload}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full p-6 space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold">ClickHouse Backfills</h1>
          <p class="text-sm text-gray-600 dark:text-gray-300 mt-1">
            Launch and monitor long running ingest jobs that pull historical xAPI events directly from S3 into ClickHouse.
          </p>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-2">
        <nav class="flex space-x-1" role="tablist">
          <button
            type="button"
            id="clickhouse-backfill-tab-manual"
            class={tab_button_classes(@active_tab == :manual)}
            phx-click="switch_tab"
            phx-value-tab="manual"
            role="tab"
            aria-selected={@active_tab == :manual}
            aria-controls="clickhouse-backfill-panel-manual"
          >
            Manual Backfill
          </button>
          <button
            type="button"
            id="clickhouse-backfill-tab-inventory"
            class={tab_button_classes(@active_tab == :inventory)}
            phx-click="switch_tab"
            phx-value-tab="batch"
            role="tab"
            aria-selected={@active_tab == :inventory}
            aria-controls="clickhouse-backfill-panel-inventory"
          >
            Inventory Backfill
          </button>
        </nav>
      </div>

      <div
        :if={@active_tab == :manual}
        id="clickhouse-backfill-panel-manual"
        role="tabpanel"
        aria-labelledby="clickhouse-backfill-tab-manual"
        tabindex="0"
        class="space-y-6"
      >
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
              <%= for {msg, _opts} <- Keyword.get_values(@changeset.errors, :clickhouse_settings) do %>
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
              <%= for {msg, _opts} <- Keyword.get_values(@changeset.errors, :options) do %>
                <p class="mt-1 text-sm text-red-600">{msg}</p>
              <% end %>
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <.button type="submit" class="btn-primary">
                Enqueue Backfill
              </.button>
            </div>
          </.form>
        </div>

        <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-5">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-xl font-semibold">Recent Runs</h2>
              <p class="text-sm text-gray-600 dark:text-gray-300">
                Showing the {length(@runs)} most recent jobs.
              </p>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700 text-sm">
              <thead class="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Run
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Status
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    S3 Pattern
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Metrics
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Timeline
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Details
                  </th>
                  <th
                    scope="col"
                    class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                  >
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for run <- @runs do %>
                  <tr class="align-top">
                    <td class="px-3 py-3 space-y-1">
                      <div class="font-semibold">Run #{run.id}</div>
                      <div class="text-xs text-gray-500 dark:text-gray-400">
                        Table: {run.target_table}
                      </div>
                      <div class="text-xs text-gray-500 dark:text-gray-400">Format: {run.format}</div>
                      <div class="text-xs text-gray-500 dark:text-gray-400">
                        Dry run: {if run.dry_run, do: "Yes", else: "No"}
                      </div>
                      <div class="text-xs text-gray-500 dark:text-gray-400">
                        Initiator: {format_initiator(run.initiated_by)}
                      </div>
                    </td>
                    <td class="px-3 py-3">
                      <span class={status_badge_classes(run.status)}>
                        {Phoenix.Naming.humanize(run.status)}
                      </span>
                      <%= if run.query_id do %>
                        <div class="mt-2 text-xs text-gray-500 break-all">
                          Query ID: {run.query_id}
                        </div>
                      <% end %>
                      <% progress_value = progress_percent(run) %>
                      <% progress_text = progress_label(run) %>
                      <div :if={progress_value} class="mt-2">
                        <div
                          class="h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden"
                          role="progressbar"
                          aria-valuemin="0"
                          aria-valuemax="100"
                          aria-valuenow={Float.round(progress_value, 1)}
                        >
                          <div
                            class="h-2 bg-blue-500 transition-all"
                            style={"width: #{Float.round(progress_value, 1)}%"}
                          >
                          </div>
                        </div>
                      </div>
                      <p :if={progress_text} class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                        {progress_text}
                      </p>
                      <%= if run.error do %>
                        <div class="mt-2 text-xs text-red-600 break-words">{run.error}</div>
                      <% end %>
                      <.button
                        :if={deletable_inventory_run?(run)}
                        phx-click="delete_inventory_run"
                        phx-value-id={run.id}
                        class="btn-danger btn-xs mt-2"
                      >
                        Delete Run
                      </.button>
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
                    <td class="px-3 py-3 text-xs text-gray-600 dark:text-gray-300">
                      <.button
                        :if={deletable_backfill_run?(run)}
                        phx-click="delete_backfill_run"
                        phx-value-id={run.id}
                        class="btn-danger btn-xs"
                      >
                        Delete Run
                      </.button>
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

      <div
        :if={@active_tab == :inventory}
        id="clickhouse-backfill-panel-inventory"
        role="tabpanel"
        aria-labelledby="clickhouse-backfill-tab-inventory"
        tabindex="0"
        class="space-y-6"
      >
        <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-5 space-y-4">
          <div class="space-y-1">
            <h2 class="text-xl font-semibold">Schedule Backfill</h2>
            <p class="text-sm text-gray-600 dark:text-gray-300">
              Select an inventory date to orchestrate ingest of all JSONL exports recorded in the S3 inventory manifest for that day.
            </p>
          </div>

          <.form
            for={@inventory_form}
            phx-change="inventory_validate"
            phx-submit="inventory_schedule"
            class="flex flex-col gap-4 w-full"
          >
            <div class="flex flex-row w-full gap-4 flex-wrap">
              <.input
                field={@inventory_form[:inventory_date]}
                type="date"
                label="Inventory Date"
                value={@inventory_form_inputs.inventory_date}
                required
              />

              <.input
                field={@inventory_form[:target_table]}
                label="Target Table"
                value={@inventory_form_inputs.target_table}
                class="flex-1"
              />
            </div>

            <details
              open={advanced_filters_open?(@inventory_form_inputs, @inventory_form)}
              class="rounded border border-gray-200 dark:border-gray-700 px-4 py-3"
            >
              <summary class="text-sm font-medium text-gray-700 dark:text-gray-200 cursor-pointer">
                Filters
              </summary>
              <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-400">
                <div class="space-y-2">
                  <div class="font-medium text-gray-700 dark:text-gray-200 text-sm">
                    Date Range (UTC)
                  </div>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    Only JSONL objects whose filenames resolve to a timestamp inside this range are ingested.
                  </p>
                  <div class="grid gap-3 md:grid-cols-2">
                    <.input
                      field={@inventory_form[:date_range_start]}
                      type="datetime-local"
                      label="Start"
                      value={@inventory_form_inputs.date_range_start}
                    />
                    <.input
                      field={@inventory_form[:date_range_end]}
                      type="datetime-local"
                      label="End"
                      value={@inventory_form_inputs.date_range_end}
                    />
                  </div>
                </div>
              </div>
            </details>

            <details
              open={
                batch_settings_open?(
                  @inventory_form_inputs,
                  @inventory_form,
                  @inventory_config,
                  @inventory_advanced_touched?
                )
              }
              class="rounded border border-gray-200 dark:border-gray-700 px-4 py-3"
            >
              <summary class="text-sm font-medium text-gray-700 dark:text-gray-200 cursor-pointer">
                Advanced
              </summary>
              <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-400">
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  Overrides apply only to this inventory run. Leave blank to use defaults.
                </p>
                <div class="grid gap-3 md:grid-cols-2">
                  <div class="space-y-1">
                    <.input
                      field={@inventory_form[:batch_chunk_size]}
                      type="number"
                      min="1"
                      label="Chunk Size (files per insert)"
                      value={@inventory_form_inputs.batch_chunk_size}
                    />
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      Number of inventory files grouped into each ClickHouse insert batch.
                    </p>
                  </div>
                  <div class="space-y-1">
                    <.input
                      field={@inventory_form[:manifest_page_size]}
                      type="number"
                      min="1"
                      label="Manifest Page Size (records)"
                      value={@inventory_form_inputs.manifest_page_size}
                    />
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      Records fetched from the manifest per request when paging the inventory list.
                    </p>
                  </div>
                  <div class="space-y-1">
                    <.input
                      field={@inventory_form[:max_simultaneous_batches]}
                      type="number"
                      min="1"
                      label="Max Simultaneous Batches"
                      value={@inventory_form_inputs.max_simultaneous_batches}
                    />
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      Maximum number of batches to process concurrently for this run.
                    </p>
                  </div>
                  <div class="space-y-1">
                    <.input
                      field={@inventory_form[:max_batch_retries]}
                      type="number"
                      min="1"
                      label="Max Batch Retries"
                      value={@inventory_form_inputs.max_batch_retries}
                    />
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      Retry attempts per batch before marking it failed.
                    </p>
                  </div>
                </div>
              </div>
            </details>

            <div>
              <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 md:col-span-4">
                <input
                  type="checkbox"
                  name="inventory[dry_run]"
                  value="true"
                  checked={truthy?(@inventory_form_inputs.dry_run)}
                  class="h-4 w-4 rounded border-gray-300 text-delivery-primary focus:ring-delivery-primary"
                />
                <span>Dry run (skip ClickHouse inserts)</span>
              </label>
            </div>

            <div class="flex items-center justify-end gap-3">
              <.button type="submit" class="btn-primary">
                Run Backfill
              </.button>
            </div>
          </.form>
        </div>

        <div class="bg-white dark:bg-gray-900 shadow rounded-lg p-5 space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-xl font-semibold">Inventory Backfill Runs</h2>
              <p class="text-sm text-gray-600 dark:text-gray-300">
                Tracks orchestrated ClickHouse ingestions driven by S3 inventory manifests.
              </p>
            </div>
          </div>

          <div :if={Enum.empty?(@inventory_runs)} class="py-8 text-center text-sm text-gray-500">
            No inventory batch runs recorded yet.
          </div>

          <div
            :for={run <- @inventory_runs}
            class="border border-gray-200 dark:border-gray-700 rounded-lg p-4 space-y-4"
          >
            <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
              <div class="space-y-1">
                <div class="text-lg font-semibold">Inventory Backfill Run #{run.id}</div>
                <div class="text-sm text-gray-600 dark:text-gray-300">
                  Inventory Date: {format_inventory_date(run.inventory_date)} · Target Table: {run.target_table}
                </div>
                <div class="text-xs text-gray-500 dark:text-gray-400">
                  Initiator: {format_initiator(run.initiated_by)}
                </div>
                <div class="text-xs text-gray-500 dark:text-gray-400">
                  Dry run: {if run.dry_run, do: "Yes", else: "No"}
                </div>
                <div
                  :if={inventory_skipped_objects(run) > 0}
                  class="text-xs text-gray-500 dark:text-gray-400"
                >
                  Skipped objects: {inventory_skipped_objects(run)}
                </div>
              </div>

              <div class="md:w-1/2 space-y-2">
                <div class="flex flex-wrap items-center gap-2">
                  <span class={status_badge_classes(run.status)}>
                    {Phoenix.Naming.humanize(run.status)}
                  </span>
                  <span class="flex-1 text-xs text-gray-500 dark:text-gray-400">
                    {inventory_progress_label(run)}
                  </span>
                  <.button
                    :if={pausable_run?(run)}
                    phx-click="pause_inventory_run"
                    phx-value-id={run.id}
                    phx-disable-with="Pausing..."
                    class="btn-warning btn-xs"
                  >
                    Pause
                  </.button>
                  <.button
                    :if={resumable_run?(run)}
                    phx-click="resume_inventory_run"
                    phx-value-id={run.id}
                    class="btn-success btn-xs"
                  >
                    Resume
                  </.button>
                  <.button
                    :if={cancellable_run?(run)}
                    phx-click="cancel_inventory_run"
                    phx-value-id={run.id}
                    class="btn-secondary btn-xs"
                  >
                    Cancel
                  </.button>
                  <.button
                    :if={deletable_inventory_run?(run)}
                    phx-click="delete_inventory_run"
                    phx-value-id={run.id}
                    class="btn-danger btn-xs"
                  >
                    Delete Run
                  </.button>
                </div>
                <% percent = inventory_percent(run) %>
                <div
                  :if={percent > 0}
                  class="h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden"
                  role="progressbar"
                  aria-valuemin="0"
                  aria-valuemax="100"
                  aria-valuenow={Float.round(percent, 1)}
                >
                  <div
                    class="h-2 bg-blue-500 transition-all"
                    style={"width: #{Float.round(percent, 1)}%"}
                  >
                  </div>
                </div>
              </div>
            </div>

            <div class="grid gap-4 md:grid-cols-4 text-xs text-gray-600 dark:text-gray-300">
              <div class="space-y-1">
                <div class="font-semibold text-gray-700 dark:text-gray-200">Batches</div>
                <div>Total: {format_int(run.total_batches)}</div>
                <div>Completed: {format_int(run.completed_batches)}</div>
                <div>Failed: {format_int(run.failed_batches)}</div>
                <div>Running: {format_int(run.running_batches)}</div>
              </div>
              <div class="space-y-1">
                <div class="font-semibold text-gray-700 dark:text-gray-200">Metrics</div>
                <div>Rows written: {format_int(run.rows_ingested)}</div>
                <div>Bytes written: {format_int(run.bytes_ingested)}</div>
              </div>
              <div class="space-y-1">
                <div class="font-semibold text-gray-700 dark:text-gray-200">Timeline</div>
                <div>Inserted: {format_timestamp(run.inserted_at)}</div>
                <div>Started: {format_timestamp(run.started_at)}</div>
                <div>Finished: {format_timestamp(run.finished_at)}</div>
              </div>
              <div class="space-y-1">
                <div class="font-semibold text-gray-700 dark:text-gray-200">Manifest</div>
                <div class="break-all text-gray-500 dark:text-gray-400">
                  <a
                    :if={run.manifest_url}
                    class="underline"
                    href={run.manifest_url}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {run.manifest_url}
                  </a>
                  <span :if={!run.manifest_url}>—</span>
                </div>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700 text-xs">
                <thead class="bg-gray-50 dark:bg-gray-800">
                  <tr>
                    <th
                      scope="col"
                      class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                    >
                      Batch
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                    >
                      Status
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                    >
                      Objects
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                    >
                      Attempts
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-2 text-left font-medium text-gray-600 dark:text-gray-300"
                    >
                      Timeline
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                  <%= for batch <- run.batches do %>
                    <tr class="align-top">
                      <td class="px-3 py-3 space-y-1">
                        <div class="font-semibold text-gray-700 dark:text-gray-200">
                          {batch.sequence}
                        </div>
                        <div class="text-gray-500 dark:text-gray-400 break-all">
                          {batch.parquet_key}
                        </div>
                      </td>
                      <td class="px-3 py-3 space-y-1">
                        <span class={status_badge_classes(batch.status)}>
                          {Phoenix.Naming.humanize(batch.status)}
                        </span>
                        <%= if batch.error do %>
                          <div class="text-red-600 break-words">{batch.error}</div>
                        <% end %>
                        <.button
                          :if={batch.status == :failed}
                          phx-click="retry_inventory_batch"
                          phx-value-id={batch.id}
                          class="btn-secondary btn-xs"
                        >
                          Retry Batch
                        </.button>
                      </td>
                      <td class="px-3 py-3 space-y-1">
                        <% progress = batch_progress(batch) %>
                        <div>Processed: {format_int(progress.processed)}</div>
                        <div>Total: {format_int(progress.total)}</div>
                        <div :if={progress.total > 0} class="space-y-1">
                          <div
                            class="h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden"
                            role="progressbar"
                            aria-valuemin="0"
                            aria-valuemax="100"
                            aria-valuenow={Float.round(progress.percent, 1)}
                          >
                            <div
                              class="h-1.5 bg-delivery-primary transition-all"
                              style={"width: #{Float.round(progress.percent, 1)}%"}
                            >
                            </div>
                          </div>
                          <div class="text-gray-500 dark:text-gray-400">
                            {Float.round(progress.percent, 1)}% complete
                          </div>
                        </div>
                      </td>
                      <td class="px-3 py-3 space-y-1">
                        <div>Attempts: {format_int(batch.attempts)}</div>
                        <div>Last attempt: {format_timestamp(batch.last_attempt_at)}</div>
                      </td>
                      <td class="px-3 py-3 space-y-1">
                        <div>Started: {format_timestamp(batch.started_at)}</div>
                        <div>Finished: {format_timestamp(batch.finished_at)}</div>
                      </td>
                    </tr>
                    <tr :if={batch_has_chunk_logs?(batch)}>
                      <td colspan="6" class="px-3 pb-3">
                        <% default_live? = batch.status == :running %>
                        <details
                          id={"chunk-logs-details-#{batch.id}"}
                          class="text-gray-600 dark:text-gray-300"
                          phx-hook="ChunkLogsDetails"
                          data-batch-id={batch.id}
                          data-default-live={if(default_live?, do: 1, else: 0)}
                        >
                          <summary class="cursor-pointer text-delivery-primary">Chunk Logs</summary>
                          <div class="mt-2">
                            <div
                              id={"chunk-logs-#{batch.id}"}
                              class="chunk-logs-viewer border border-gray-200 dark:border-gray-700 rounded"
                              data-batch-id={batch.id}
                              data-limit="10"
                              data-window="200"
                              data-initial-count={batch_chunk_log_count(batch)}
                              data-default-live={if(default_live?, do: 1, else: 0)}
                              data-user-token={@user_token || ""}
                              phx-hook="ChunkLogsViewer"
                              phx-update="ignore"
                            >
                              <div class="flex items-center justify-end text-xs text-gray-600 dark:text-gray-300 border-b border-gray-200 dark:border-gray-700 px-2 py-1">
                                <label class="inline-flex items-center gap-2 select-none">
                                  <input
                                    type="checkbox"
                                    class="chunk-logs-live-toggle h-3.5 w-3.5 rounded border-gray-300 text-delivery-primary focus:ring-delivery-primary"
                                    data-default-live={if(default_live?, do: 1, else: 0)}
                                    checked={default_live?}
                                  />
                                  <span>Live update</span>
                                </label>
                              </div>
                              <div class="chunk-logs-scroll max-h-80 overflow-y-auto text-xs">
                                <div class="chunk-logs-top-sentinel h-4"></div>
                                <div class="chunk-logs-body space-y-2 px-2 py-2"></div>
                                <div class="chunk-logs-bottom-sentinel h-4"></div>
                              </div>
                              <div
                                class="chunk-logs-status text-xs text-gray-500 dark:text-gray-400 px-2 py-1 hidden"
                                role="status"
                                aria-live="polite"
                                aria-atomic="true"
                              >
                              </div>
                            </div>
                          </div>
                        </details>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp breadcrumbs do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "ClickHouse Backfills",
          link: ~p"/admin/clickhouse/backfill"
        })
      ]
  end

  defp normalize_form_params(params) do
    params = Map.new(params || %{})
    original_pattern = params |> Map.get("s3_pattern", "") |> String.trim()

    with {:ok, s3_pattern} <- normalize_s3_pattern(original_pattern) do
      target_table =
        params |> Map.get("target_table", Backfill.default_target_table()) |> String.trim()

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
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:ok, _other} ->
        {:error, {field, "must be a JSON object"}}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, {field, "invalid JSON: #{Exception.message(error)}"}}
    end
  end

  defp truthy?(value) when value in [true, "true", "1", 1, "on", "yes"], do: true
  defp truthy?(_), do: false

  defp normalize_s3_pattern(pattern) when is_binary(pattern) do
    trimmed = String.trim(pattern || "")

    cond do
      trimmed == "" ->
        {:ok, ""}

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

    assign(socket,
      runs: Backfill.list_runs(limit: @runs_limit),
      inventory_runs: Inventory.list_runs(limit: @inventory_runs_limit)
    )
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
      target_table:
        Map.get(params, "target_table", Backfill.default_target_table()) |> String.trim(),
      format: Map.get(params, "format", "JSONAsString") |> String.trim(),
      dry_run: truthy?(Map.get(params, "dry_run")),
      clickhouse_settings: Map.get(params, "clickhouse_settings", "") |> String.trim(),
      options: Map.get(params, "options", "") |> String.trim()
    }
  end

  defp inventory_default_inputs(config) do
    default_date =
      Date.utc_today()
      |> Date.add(-1)

    %{
      inventory_date: default_date,
      target_table: Backfill.default_target_table(),
      dry_run: false,
      date_range_start: nil,
      date_range_end: nil,
      batch_chunk_size: inventory_chunk_size(config),
      manifest_page_size: inventory_manifest_page_size(config),
      max_simultaneous_batches: inventory_max_simultaneous_batches(config),
      max_batch_retries: inventory_max_batch_retries(config)
    }
  end

  defp inventory_form_changeset(attrs, config) do
    data = inventory_default_inputs(config)

    types = %{
      inventory_date: :date,
      target_table: :string,
      dry_run: :boolean,
      date_range_start: :string,
      date_range_end: :string,
      batch_chunk_size: :integer,
      manifest_page_size: :integer,
      max_simultaneous_batches: :integer,
      max_batch_retries: :integer
    }

    {data, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([
      :inventory_date
    ])
    |> Ecto.Changeset.update_change(:target_table, &normalize_target_table/1)
    |> Ecto.Changeset.validate_length(:target_table, max: 255)
    |> Ecto.Changeset.validate_format(:target_table, ~r/^[a-zA-Z0-9_\.]+$/)
    |> parse_datetime_change(:date_range_start)
    |> parse_datetime_change(:date_range_end)
    |> validate_inventory_date_range()
    |> Ecto.Changeset.validate_number(:batch_chunk_size, greater_than: 0)
    |> Ecto.Changeset.validate_number(:manifest_page_size, greater_than: 0)
    |> Ecto.Changeset.validate_number(:max_simultaneous_batches, greater_than: 0)
    |> Ecto.Changeset.validate_number(:max_batch_retries, greater_than: 0)
  end

  defp inventory_chunk_size(config) do
    config
    |> inventory_config_value(:batch_chunk_size, 25)
    |> parse_positive_integer(25)
  end

  defp inventory_manifest_page_size(config) do
    chunk_size = inventory_chunk_size(config)

    config
    |> inventory_config_value(:manifest_page_size, nil)
    |> parse_positive_integer(nil)
    |> case do
      nil -> max(chunk_size * 20, 1_000)
      value -> value
    end
  end

  defp inventory_max_simultaneous_batches(config) do
    config
    |> inventory_config_value(:max_simultaneous_batches, 1)
    |> parse_positive_integer(1)
  end

  defp inventory_max_batch_retries(config) do
    config
    |> inventory_config_value(:max_batch_retries, 1)
    |> parse_positive_integer(1)
  end

  defp inventory_config_value(config, key, default) do
    value =
      cond do
        is_map(config) and Map.has_key?(config, key) ->
          Map.get(config, key)

        is_map(config) and Map.has_key?(config, Atom.to_string(key)) ->
          Map.get(config, Atom.to_string(key))

        true ->
          nil
      end

    case value do
      nil -> default
      "" -> default
      _ -> value
    end
  end

  defp parse_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp parse_positive_integer(value, default) when is_integer(value), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_value, default), do: default

  defp inventory_form_values(inputs, config) do
    defaults = inventory_default_inputs(config)

    %{
      inventory_date:
        inputs
        |> Map.get(:inventory_date)
        |> Kernel.||(Map.get(inputs, "inventory_date"))
        |> format_date_input(),
      target_table:
        inputs
        |> Map.get(:target_table)
        |> Kernel.||(Map.get(inputs, "target_table"))
        |> ensure_target_table(),
      dry_run:
        inputs
        |> Map.get(:dry_run)
        |> Kernel.||(Map.get(inputs, "dry_run"))
        |> truthy?(),
      date_range_start:
        inputs
        |> Map.get(:date_range_start)
        |> Kernel.||(Map.get(inputs, "date_range_start"))
        |> format_datetime_input(),
      date_range_end:
        inputs
        |> Map.get(:date_range_end)
        |> Kernel.||(Map.get(inputs, "date_range_end"))
        |> format_datetime_input(),
      batch_chunk_size:
        inputs
        |> Map.get(:batch_chunk_size)
        |> Kernel.||(Map.get(inputs, "batch_chunk_size"))
        |> Kernel.||(Map.get(defaults, :batch_chunk_size))
        |> format_integer_input(),
      manifest_page_size:
        inputs
        |> Map.get(:manifest_page_size)
        |> Kernel.||(Map.get(inputs, "manifest_page_size"))
        |> Kernel.||(Map.get(defaults, :manifest_page_size))
        |> format_integer_input(),
      max_simultaneous_batches:
        inputs
        |> Map.get(:max_simultaneous_batches)
        |> Kernel.||(Map.get(inputs, "max_simultaneous_batches"))
        |> Kernel.||(Map.get(defaults, :max_simultaneous_batches))
        |> format_integer_input(),
      max_batch_retries:
        inputs
        |> Map.get(:max_batch_retries)
        |> Kernel.||(Map.get(inputs, "max_batch_retries"))
        |> Kernel.||(Map.get(defaults, :max_batch_retries))
        |> format_integer_input()
    }
  end

  defp inventory_inputs_from_params(params, config) do
    params = Map.new(params || %{})
    defaults = inventory_default_inputs(config)

    date = params |> Map.get("inventory_date", "") |> String.trim()
    target = params |> Map.get("target_table", "") |> String.trim()
    dry_run = truthy?(Map.get(params, "dry_run"))
    range_start = params |> Map.get("date_range_start", "") |> String.trim()
    range_end = params |> Map.get("date_range_end", "") |> String.trim()
    chunk_size = params |> Map.get("batch_chunk_size", "") |> String.trim()
    page_size = params |> Map.get("manifest_page_size", "") |> String.trim()
    max_simultaneous = params |> Map.get("max_simultaneous_batches", "") |> String.trim()
    max_retries = params |> Map.get("max_batch_retries", "") |> String.trim()

    %{
      inventory_date: date,
      target_table: if(target == "", do: Backfill.default_target_table(), else: target),
      dry_run: dry_run,
      date_range_start: range_start,
      date_range_end: range_end,
      batch_chunk_size: if(chunk_size == "", do: defaults.batch_chunk_size, else: chunk_size),
      manifest_page_size: if(page_size == "", do: defaults.manifest_page_size, else: page_size),
      max_simultaneous_batches:
        if(max_simultaneous == "", do: defaults.max_simultaneous_batches, else: max_simultaneous),
      max_batch_retries: if(max_retries == "", do: defaults.max_batch_retries, else: max_retries)
    }
  end

  defp inventory_percent(%InventoryRun{} = run) do
    total = run.total_batches || 0
    completed = run.completed_batches || 0

    cond do
      total > 0 -> completed / total * 100.0
      true -> 0.0
    end
  end

  defp inventory_progress_label(%InventoryRun{} = run) do
    total = run.total_batches || 0
    completed = run.completed_batches || 0
    failed = run.failed_batches || 0
    running = run.running_batches || 0
    pending = run.pending_batches || 0
    batches = run.batches || []
    paused = Enum.count(batches, &(&1.status == :paused))
    skipped = inventory_skipped_objects(run)

    segments =
      []
      |> append_segment(failed > 0, "#{failed} failed")
      |> append_segment(running > 0, "#{running} running")
      |> append_segment(paused > 0, "#{paused} paused")
      |> append_segment(pending > 0, "#{pending} pending")
      |> append_segment(skipped > 0, "#{skipped} skipped")

    base =
      cond do
        total == 0 and run.status == :completed -> "No batches required"
        total == 0 and run.status in [:failed, :cancelled] -> "No batches prepared"
        total == 0 -> "Preparing batches"
        true -> "#{completed} of #{total} completed"
      end

    if total == 0 or Enum.empty?(segments) do
      base
    else
      base <> " · " <> Enum.join(segments, " · ")
    end
  end

  defp cancellable_run?(%InventoryRun{status: status})
       when status in [:pending, :preparing, :running, :paused],
       do: true

  defp cancellable_run?(_), do: false

  defp pausable_run?(%InventoryRun{} = run) do
    metadata = ensure_map(run.metadata)

    run.status in [:running, :preparing, :pending] and
      not truthy?(Map.get(metadata, "pause_requested"))
  end

  defp pausable_run?(_), do: false

  defp resumable_run?(%InventoryRun{} = run) do
    metadata = ensure_map(run.metadata)
    run.status == :paused or truthy?(Map.get(metadata, "pause_requested"))
  end

  defp resumable_run?(_), do: false

  defp append_segment(segments, false, _value), do: segments
  defp append_segment(segments, true, value), do: segments ++ [value]

  defp metadata_id(metadata, key) do
    metadata = Map.new(metadata || %{})
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp update_inventory_run_assign(socket, run_id) do
    try do
      run = Inventory.get_run!(run_id)
      runs = upsert_inventory_run(socket.assigns.inventory_runs, run)
      assign(socket, :inventory_runs, runs)
    rescue
      Ecto.NoResultsError ->
        pruned =
          socket.assigns.inventory_runs
          |> Enum.reject(&(&1.id == run_id))

        replenished =
          if length(pruned) < @inventory_runs_limit do
            Inventory.list_runs(limit: @inventory_runs_limit)
          else
            pruned
          end

        assign(socket, :inventory_runs, replenished)
    end
  end

  defp upsert_inventory_run(runs, run) do
    runs
    |> Enum.reject(&(&1.id == run.id))
    |> List.insert_at(0, run)
    |> Enum.sort_by(&run_sort_key/1, {:desc, DateTime})
    |> Enum.take(@inventory_runs_limit)
  end

  defp run_sort_key(%{inserted_at: %DateTime{} = dt}), do: dt
  defp run_sort_key(_), do: ~U[1970-01-01 00:00:00Z]

  defp ensure_target_table(value) do
    value
    |> normalize_target_table()
  end

  defp normalize_target_table(value) when value in [nil, ""], do: Backfill.default_target_table()
  defp normalize_target_table(value) when is_binary(value), do: String.trim(value)
  defp normalize_target_table(value), do: value |> to_string() |> String.trim()

  defp format_inventory_date(nil), do: "—"
  defp format_inventory_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_inventory_date(value), do: to_string(value)

  defp format_date_input(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date_input(value) when is_binary(value), do: value
  defp format_date_input(_), do: ""

  defp format_datetime_input(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")
  end

  defp format_datetime_input(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")
  end

  defp format_datetime_input(value) when is_binary(value), do: value
  defp format_datetime_input(_), do: ""

  defp format_integer_input(value) when is_integer(value), do: Integer.to_string(value)
  defp format_integer_input(value) when is_binary(value), do: value
  defp format_integer_input(_), do: ""

  defp parse_datetime_change(changeset, field) do
    case Ecto.Changeset.fetch_change(changeset, field) do
      {:ok, value} ->
        case parse_datetime_value(value) do
          {:ok, parsed} ->
            Ecto.Changeset.put_change(changeset, field, parsed)

          {:error, message} ->
            Ecto.Changeset.add_error(changeset, field, message)
        end

      :error ->
        changeset
    end
  end

  defp parse_datetime_value(value) when value in [nil, ""], do: {:ok, nil}
  defp parse_datetime_value(%DateTime{} = value), do: {:ok, value}

  defp parse_datetime_value(%NaiveDateTime{} = value) do
    {:ok, DateTime.from_naive!(value, "Etc/UTC")}
  rescue
    ArgumentError -> {:error, "invalid datetime"}
  end

  defp parse_datetime_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        {:ok, nil}

      true ->
        with {:ok, datetime, _offset} <- DateTime.from_iso8601(trimmed) do
          {:ok, datetime}
        else
          _ ->
            trimmed
            |> ensure_seconds_component()
            |> NaiveDateTime.from_iso8601()
            |> case do
              {:ok, naive} ->
                {:ok, DateTime.from_naive!(naive, "Etc/UTC")}

              {:error, _} ->
                {:error, "invalid datetime"}
            end
        end
    end
  end

  defp parse_datetime_value(_), do: {:error, "invalid datetime"}

  defp ensure_seconds_component(value) do
    cond do
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}$/, value) ->
        value <> ":00"

      true ->
        value
    end
  end

  defp validate_inventory_date_range(changeset) do
    start_datetime = Ecto.Changeset.get_field(changeset, :date_range_start)
    end_datetime = Ecto.Changeset.get_field(changeset, :date_range_end)

    cond do
      is_nil(start_datetime) or is_nil(end_datetime) ->
        changeset

      DateTime.compare(start_datetime, end_datetime) in [:lt, :eq] ->
        changeset

      true ->
        Ecto.Changeset.add_error(changeset, :date_range_end, "must be after start")
    end
  end

  defp advanced_filters_open?(inputs, form) do
    start_input =
      inputs
      |> Map.get(:date_range_start)
      |> Kernel.||(Map.get(inputs, "date_range_start"))

    end_input =
      inputs
      |> Map.get(:date_range_end)
      |> Kernel.||(Map.get(inputs, "date_range_end"))

    has_value? = present?(start_input) or present?(end_input)

    has_error? =
      Enum.any?(
        [
          form[:date_range_start].errors,
          form[:date_range_end].errors
        ],
        fn errors ->
          match?([{_, _} | _], errors)
        end
      )

    has_value? or has_error?
  end

  defp batch_settings_open?(inputs, form, config, touched?) do
    if not touched? do
      false
    else
      defaults = inventory_default_inputs(config)

      chunk_size =
        inputs
        |> Map.get(:batch_chunk_size)
        |> Kernel.||(Map.get(inputs, "batch_chunk_size"))

      page_size =
        inputs
        |> Map.get(:manifest_page_size)
        |> Kernel.||(Map.get(inputs, "manifest_page_size"))

      max_simultaneous =
        inputs
        |> Map.get(:max_simultaneous_batches)
        |> Kernel.||(Map.get(inputs, "max_simultaneous_batches"))

      max_retries =
        inputs
        |> Map.get(:max_batch_retries)
        |> Kernel.||(Map.get(inputs, "max_batch_retries"))

      raw_params = Map.new(form.params || %{})

      has_raw_input? =
        Enum.any?(
          [
            "batch_chunk_size",
            "manifest_page_size",
            "max_simultaneous_batches",
            "max_batch_retries"
          ],
          &Map.has_key?(raw_params, &1)
        )

      has_value? =
        Enum.any?(
          [
            {chunk_size, defaults.batch_chunk_size},
            {page_size, defaults.manifest_page_size},
            {max_simultaneous, defaults.max_simultaneous_batches},
            {max_retries, defaults.max_batch_retries}
          ],
          fn {value, default} ->
            cond do
              present?(value) ->
                parsed = parse_positive_integer(value, default)
                parsed != default

              true ->
                false
            end
          end
        )

      has_error? =
        Enum.any?(
          [
            form[:batch_chunk_size].errors,
            form[:manifest_page_size].errors,
            form[:max_simultaneous_batches].errors,
            form[:max_batch_retries].errors
          ],
          fn errors ->
            match?([{_, _} | _], errors)
          end
        )

      has_raw_input? or has_value? or has_error?
    end
  end

  defp present?(value) when value in [nil, ""], do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: true

  defp inventory_skipped_objects(%InventoryRun{} = run) do
    Inventory.skipped_objects(run)
  end

  defp inventory_skipped_objects(_), do: 0

  defp resolve_active_tab(params) do
    params
    |> fetch_active_tab_param()
    |> case do
      value when value in ["batch", "inventory", :batch, :inventory] -> :inventory
      "manual" -> :manual
      :manual -> :manual
      _ -> :inventory
    end
  end

  defp fetch_active_tab_param(params) when is_map(params) do
    Map.get(params, "active_tab") || Map.get(params, :active_tab)
  end

  defp fetch_active_tab_param(_), do: nil

  defp active_tab_path(_socket, tab) do
    ~p"/admin/clickhouse/backfill?#{[active_tab: active_tab_param(tab)]}"
  end

  defp active_tab_param(:inventory), do: "batch"
  defp active_tab_param(:manual), do: "manual"

  defp batch_chunk_log_count(%InventoryBatch{metadata: metadata}) do
    metadata
    |> ensure_map()
    |> Map.get("chunk_count", 0)
    |> parse_non_negative_integer(0)
  end

  defp batch_chunk_log_count(_), do: 0

  defp batch_has_chunk_logs?(batch), do: batch_chunk_log_count(batch) > 0

  defp batch_progress(%InventoryBatch{} = batch) do
    total = batch.object_count || 0
    processed = batch.processed_objects || 0

    percent =
      cond do
        total <= 0 ->
          0.0

        true ->
          processed
          |> Kernel./(total)
          |> Kernel.*(100.0)
          |> min(100.0)
          |> max(0.0)
      end

    %{percent: percent, processed: processed, total: total}
  end

  defp deletable_backfill_run?(%BackfillRun{status: status})
       when status in [:completed, :failed, :cancelled],
       do: true

  defp deletable_backfill_run?(_), do: false

  defp deletable_inventory_run?(%InventoryRun{status: status})
       when status in [:completed, :failed, :cancelled],
       do: true

  defp deletable_inventory_run?(_), do: false

  defp ensure_map(nil), do: %{}
  defp ensure_map(map) when is_map(map), do: map
  defp ensure_map(_), do: %{}

  defp parse_non_negative_integer(value, _default) when is_integer(value) and value >= 0,
    do: value

  defp parse_non_negative_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int >= 0 -> int
      _ -> default
    end
  end

  defp parse_non_negative_integer(_, default), do: default

  defp tab_button_classes(true) do
    "px-4 py-2 text-sm font-medium border-b-2 border-delivery-primary text-delivery-primary"
  end

  defp tab_button_classes(false) do
    "px-4 py-2 text-sm font-medium border-b-2 border-transparent text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
  end

  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp status_badge_classes(:completed),
    do:
      "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-green-100 text-green-800"

  defp status_badge_classes(status) when status in [:running, :preparing],
    do:
      "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-blue-100 text-blue-800"

  defp status_badge_classes(:failed),
    do: "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-red-100 text-red-800"

  defp status_badge_classes(:cancelled),
    do:
      "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-yellow-100 text-yellow-800"

  defp status_badge_classes(_),
    do:
      "inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-gray-100 text-gray-800"

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

      _ ->
        nil
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
