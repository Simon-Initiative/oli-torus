defmodule OliWeb.GenAI.ProvidersView do
  use OliWeb, :live_view
  on_mount OliWeb.GenAI.AdminMount
  alias Oli.GenAI
  alias Oli.GenAI.{Diagnostics, Provider}

  @doc "Loads Provider administration with write-only credential fields."
  def mount(_, _, socket) do
    socket =
      assign(socket,
        providers: GenAI.providers(),
        model_names: Map.new(GenAI.registered_models(), &{&1.id, &1.name}),
        selected: %Provider{},
        editing: false,
        diagnostics: Diagnostics.snapshot(),
        breadcrumbs: []
      )
      |> form(Ecto.Changeset.change(%Provider{}))

    case connected?(socket) do
      true -> Process.send_after(self(), :refresh, 5_000)
      false -> :ok
    end

    {:ok, socket}
  end

  @doc "Renders connection configuration separately from independently observed health."
  def render(assigns) do
    ~H"""
    <main class="space-y-4 p-4">
      <h1 class="text-xl font-semibold">GenAI Providers</h1>
      <nav class="flex gap-4" aria-label="GenAI administration">
        <.link navigate={~p"/admin/gen_ai/registered_models"}>Models</.link>
        <.link navigate={~p"/admin/gen_ai/service_configs"}>Service configurations</.link>
      </nav>
      <p>
        Availability comes only from independent probes. Status and capacity are local to this node.
      </p>
      <p :if={@diagnostics.health.error} role="status">Runtime: {@diagnostics.health.error}</p>
      <p :if={@selected.adapter == :claude} role="status">
        Claude runtime still uses legacy model connection settings. Provider credential edits do not rotate existing Claude model credentials; managed transport tests remain deferred.
      </p>
      <button
        id="toggle_editing"
        type="button"
        phx-click="toggle_editing"
        aria-pressed={to_string(@editing)}
        class="rounded border px-3 py-2"
      >
        {case @editing do
          true -> "Disable editing"
          false -> "Enable editing"
        end}
      </button>
      <ul aria-label="Providers" class="space-y-2">
        <li :for={provider <- @providers}>
          <button
            type="button"
            phx-click="select"
            phx-value-id={provider.id}
            aria-pressed={to_string(@selected.id == provider.id)}
            class="rounded border px-3 py-2"
          >
            {provider.name} ({provider.adapter})
          </button>
          <span>{Diagnostics.status(@diagnostics.health.providers[provider.id])}</span>
        </li>
      </ul>
      <button type="button" phx-click="new" disabled={!@editing} class="rounded border px-3 py-2">
        New Provider
      </button>
      <section aria-label="Selected Provider health" class="rounded border p-3">
        <%= case @diagnostics.health.providers[@selected.id] do %>
          <% nil -> %>
            <p>Unknown: no monitor snapshot</p>
          <% health -> %>
            <dl class="grid grid-cols-2 gap-2">
              <dt>Administrative state</dt>
              <dd>
                {case health.administrative_enabled do
                  true -> "Enabled"
                  false -> "Disabled"
                end}
              </dd>
              <dt>Observed availability</dt>
              <dd>{Diagnostics.status(health)}</dd>
              <dt>Selected health-check model ID</dt>
              <dd>
                {Map.get(@model_names, health.health_check_model_id, "Missing model")} (ID {health.health_check_model_id ||
                  "none"})
              </dd>
              <dt>Last check</dt>
              <dd>{time(health.last_check)}</dd>
              <dt>Last success</dt>
              <dd>{time(health.last_success)}</dd>
              <dt>Next check</dt>
              <dd>{time(health.next_check)}</dd>
              <dt>Consecutive failures / successes</dt>
              <dd>{health.consecutive_failures} / {health.consecutive_successes}</dd>
              <dt>Diagnostic category</dt>
              <dd>{health.failure_category || "None"}</dd>
            </dl>
        <% end %>
      </section>
      <.form for={@form} id="provider-form" phx-submit="save" class="max-w-2xl space-y-3">
        <.input field={@form[:name]} label="Provider name" disabled={!@editing} />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:adapter]}
          type="select"
          label="Transport adapter"
          options={[
            {"OpenAI HTTP/1.1", :open_ai},
            {"Claude (transport deferred)", :claude},
            {"Local null", :null}
          ]}
          disabled={!@editing or not is_nil(@selected.id)}
        />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:enabled]}
          type="checkbox"
          label="Administratively enabled"
          disabled={!@editing}
        />
        <.input field={@form[:base_url]} label="Base URL or endpoint template" disabled={!@editing} />
        <p id="credential-help">Credentials are write-only. Leave blank to retain existing keys.</p>
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:api_key]}
          type="password"
          value=""
          autocomplete="new-password"
          label="API key"
          aria-describedby="credential-help"
          disabled={!@editing}
        />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:organization_key]}
          type="password"
          value=""
          autocomplete="new-password"
          label="Organization key"
          aria-describedby="credential-help"
          disabled={!@editing}
        />
        <label class="flex gap-2">
          <input
            type="checkbox"
            name="provider[clear_organization_key]"
            value="true"
            disabled={!@editing}
          /> Clear stored organization key
        </label>
        <p>Endpoint templates may use :model, :api_key and :secondary_api_key placeholders.</p>
        <p>Blank probe settings inherit runtime defaults. Durations are milliseconds.</p>
        <.input
          :for={
            {field, label} <- [
              probe_interval_ms: "Regular / recovery interval (ms)",
              probe_failure_interval_ms: "Suspected failure interval (ms)",
              probe_deadline_ms: "Probe deadline (ms)",
              failure_threshold: "Failures to mark unavailable",
              recovery_threshold: "Successes to recover"
            ]
          }
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[field]}
          type="number"
          min="1"
          label={label}
          disabled={!@editing}
        />
        <button type="submit" disabled={!@editing} class="rounded bg-blue-700 px-4 py-2 text-white">
          Save Provider
        </button>
        <button
          type="button"
          phx-click="delete"
          disabled={!@editing or is_nil(@selected.id)}
          data-confirm="Delete this unreferenced Provider?"
          class="rounded border px-4 py-2"
        >
          Delete Provider
        </button>
      </.form>
    </main>
    """
  end

  def handle_event("toggle_editing", _, socket),
    do: {:noreply, assign(socket, editing: !socket.assigns.editing)}

  def handle_event(event, _, %{assigns: %{editing: false}} = socket)
      when event in ["save", "delete", "new"],
      do: {:noreply, put_flash(socket, :error, "Enable editing first")}

  def handle_event("new", _, socket),
    do:
      {:noreply,
       socket |> assign(selected: %Provider{}) |> form(Ecto.Changeset.change(%Provider{}))}

  def handle_event("select", %{"id" => id}, socket) do
    case Enum.find(GenAI.providers(), &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Provider not found")}

      provider ->
        {:noreply,
         socket
         |> assign(selected: %{provider | api_key: nil, organization_key: nil})
         |> form(Ecto.Changeset.change(provider))}
    end
  end

  def handle_event("save", %{"provider" => params}, socket) do
    params =
      Map.take(
        params,
        ~w(name adapter enabled base_url api_key organization_key clear_organization_key probe_interval_ms probe_failure_interval_ms probe_deadline_ms failure_threshold recovery_threshold)
      )

    params =
      case socket.assigns.selected.id do
        nil ->
          params

        _ ->
          params
          |> Map.reject(fn {k, v} -> k in ["api_key", "organization_key"] and v == "" end)
          |> Map.delete("adapter")
      end

    params =
      case params["clear_organization_key"] do
        "true" -> Map.put(params, "organization_key", nil)
        _ -> params
      end

    result =
      case socket.assigns.selected.id do
        nil -> GenAI.create_provider(params)
        _ -> GenAI.update_provider(socket.assigns.selected, params)
      end

    case result do
      {:ok, provider} ->
        {:noreply,
         socket
         |> assign(
           providers: GenAI.providers(),
           selected: %{provider | api_key: nil, organization_key: nil},
           editing: false
         )
         |> form(Ecto.Changeset.change(provider))
         |> put_flash(:info, "Provider saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, form(socket, changeset)}

      _ ->
        {:noreply, put_flash(socket, :error, "Provider could not be saved")}
    end
  end

  def handle_event("delete", _, socket) do
    case GenAI.delete_provider(socket.assigns.selected) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(providers: GenAI.providers(), selected: %Provider{}, editing: false)
         |> form(Ecto.Changeset.change(%Provider{}))}

      _ ->
        {:noreply,
         put_flash(socket, :error, "Provider is still referenced or could not be deleted")}
    end
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, 5_000)

    {:noreply,
     assign(socket,
       diagnostics: Diagnostics.snapshot(),
       providers: GenAI.providers(),
       model_names: Map.new(GenAI.registered_models(), &{&1.id, &1.name})
     )}
  end

  defp time(nil), do: "None"
  defp time(value), do: to_string(value)

  defp form(socket, cs) do
    # Never return stored or just-submitted credentials in LiveView diffs or form params.
    keys = [
      Ecto.Changeset.get_field(cs, :api_key),
      Ecto.Changeset.get_field(cs, :organization_key)
    ]

    data = %{
      cs.data
      | api_key: nil,
        organization_key: nil,
        base_url: safe_url(cs.data.base_url, keys)
    }

    changes = Map.drop(cs.changes, [:api_key, :organization_key])

    changes =
      case changes[:base_url] do
        nil -> changes
        url -> Map.put(changes, :base_url, safe_url(url, keys))
      end

    params = Map.drop(cs.params || %{}, ["api_key", "organization_key"])

    params =
      case params["base_url"] do
        nil -> params
        url -> Map.put(params, "base_url", safe_url(url, keys))
      end

    cs = %{cs | data: data, changes: changes, params: params}
    assign(socket, form: to_form(cs, as: :provider))
  end

  defp safe_url(nil, _), do: nil

  defp safe_url(url, keys) do
    Enum.zip(keys, [":api_key", ":secondary_api_key"])
    |> Enum.reduce(url, fn
      {key, replacement}, acc when is_binary(key) and byte_size(key) > 0 ->
        String.replace(acc, key, replacement)

      _, acc ->
        acc
    end)
  end
end
