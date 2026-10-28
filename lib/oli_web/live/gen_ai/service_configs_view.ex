defmodule OliWeb.GenAI.ServiceConfigsView do
  use OliWeb, :live_view
  on_mount OliWeb.GenAI.AdminMount

  require Logger

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{ServiceConfig}
  alias Oli.GenAI.{Administrative, Diagnostics}
  alias OliWeb.Common.Breadcrumb

  @form_control_classes "block w-full p-2.5
  text-sm text-gray-900 bg-gray-50
  rounded-lg border border-gray-300
  focus:ring-blue-500 focus:border-blue-500
  dark:bg-gray-700 dark:border-gray-600
  dark:placeholder-gray-400 dark:text-white"
  @health_refresh_ms 5_000

  def mount(_, _session, socket) do
    all = all()
    selected = Enum.at(all, 0) || %ServiceConfig{}
    changeset = Ecto.Changeset.change(selected)

    registered_models = all_registered_models()

    socket =
      socket
      |> assign(editing: false, testing: false, test_results: "")
      |> assign(selected: selected)
      |> assign(service_configs: all)
      |> assign(registered_models: registered_models)
      |> assign(breadcrumbs: breadcrumb())
      |> assign_form(changeset)
      |> assign_health(selected)
      |> schedule_health_refresh()

    {:ok, socket}
  end

  attr :service_configs, :list, required: true
  attr :registered_models, :list, required: true
  attr(:selected, ServiceConfig)
  attr :breadcrumbs, :any
  attr :form, :any
  attr :title, :string, default: "Completions Service Configurations"
  attr :editing, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <h1 class="text-xl font-semibold">Completions Service Configurations</h1>
      <div class="flex justify-end">
        <div class="flex py-2 mb-2">
          <div>Enable Editing</div>
          <.toggle_switch
            id="toggle_editing"
            class="ml-4"
            checked={@editing}
            on_toggle="toggle_editing"
            name="toggle_editing"
          />
        </div>
      </div>
      <div class="flex gap-3">
        <.link navigate={~p"/admin/gen_ai/providers"}>Providers and health</.link>
        <.link navigate={~p"/admin/gen_ai/registered_models"}>Registered models</.link>
        <button
          type="button"
          phx-click="test"
          disabled={@testing or is_nil(@selected.id)}
          class="rounded border px-3 py-2"
        >
          Test Service Config
        </button>
        <p role="status" aria-live="polite">{@test_results}</p>
      </div>
      <div class="flex flex-col gap-4 lg:flex-row">
        <div class="flex w-full flex-col lg:w-1/2">
          <p :if={@service_configs == []}>
            No service configurations yet. Configure a Provider and model, then create a service configuration.
          </p>
          <ul role="list" class="divide-y divide-gray-100">
            <%= for service_config <- @service_configs do %>
              <.service_config service_config={service_config} selected={@selected} />
            <% end %>
          </ul>
          <div class="mt-3">
            <button disabled={!@editing} class="btn btn-primary btn-sm" phx-click="new">
              + New Service Config
            </button>
          </div>
        </div>

        <.selected_item
          registered_models={@registered_models}
          selected={@selected}
          form={@form}
          health={@health}
          issues={@issues}
          editing={@editing}
        />
      </div>
    </div>
    """
  end

  attr(:service_config, ServiceConfig)
  attr(:selected, ServiceConfig)

  def service_config(assigns) do
    ~H"""
    <li>
      <button
        type="button"
        phx-click="select"
        phx-value-id={@service_config.id}
        aria-pressed={to_string(@selected.id == @service_config.id)}
        class={
          [
            # base
            "flex justify-between gap-x-6 py-1 px-2 rounded-md cursor-pointer transition-colors bg-white dark:bg-gray-900 dark:text-gray-100",

            # selected (non-hover)
            @selected.id == @service_config.id && "bg-indigo-50 dark:bg-gray-700 ",

            # hover (overrides both unselected and selected)
            "hover:bg-indigo-100 dark:hover:bg-gray-600"
          ]
        }
      >
        <div class="flex flex-col min-w-0 gap-x-4">
          <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
            {@service_config.name}
          </h3>
          <div class="flex">
            <div class="mr-5">
              <span class="text-gray-800 text-xs py-0.5">Primary: </span>
              <span class="text-gray-800 text-xs font-mono py-0.5 ">
                {case @service_config.primary_model do
                  nil -> "Missing model"
                  model -> model.name
                end}
              </span>
            </div>
            <div class="mr-5">
              <span class="text-gray-800 text-xs py-0.5">Secondary: </span>
              <span class="text-gray-800 text-xs font-mono py-0.5">
                {if is_nil(@service_config.secondary_model) do
                  "None"
                else
                  @service_config.secondary_model.name
                end}
              </span>
            </div>
            <div>
              <span class="text-gray-800 text-xs py-0.5">Backup: </span>
              <span class="text-gray-800 text-xs font-mono py-0.5">
                {if is_nil(@service_config.backup_model) do
                  "None"
                else
                  @service_config.backup_model.name
                end}
              </span>
            </div>
          </div>
        </div>
        <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
          <%= if @service_config.usage_count > 0 do %>
            <p class="mt-0 text-xs text-gray-500">
              Used by <strong>{@service_config.usage_count}</strong> feature config(s)
            </p>
          <% else %>
            <p class="mt-0 text-xs text-red-500">
              No usages
            </p>
          <% end %>
        </div>
      </button>
    </li>
    """
  end

  attr(:selected, ServiceConfig)
  attr :form, :any
  attr :health, :list, default: []
  attr :issues, :list, default: []
  attr :editing, :boolean, default: false
  attr :registered_models, :list, required: true

  def selected_item(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="w-full p-4 lg:w-1/2">
      <.form for={@form} id="service-config-form" phx-submit="save">
        <.input
          field={@form[:name]}
          label="Friendly Name"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={@form[:primary_model_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={@registered_models}
          label="Primary Registered Model"
        />
        <.input
          field={@form[:secondary_model_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={[{"No secondary", nil} | @registered_models]}
          label="Secondary Registered Model"
        />
        <.input
          field={@form[:backup_model_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={[{"No backup", nil} | @registered_models]}
          label="Backup Registered Model"
        />

        <.input
          :for={
            {field, label} <- [
              primary_pool_capacity: "Primary pool capacity — Maximum checked-out connections",
              secondary_pool_capacity: "Secondary pool capacity — Maximum checked-out connections",
              backup_pool_capacity: "Backup pool capacity — Maximum checked-out connections"
            ]
          }
          field={@form[field]}
          type="number"
          min="1"
          label={label}
          disabled={!@editing}
        />
        <p class="text-sm">
          Capacity is per node. HTTP/1.1 streams retain one connection. Capacity changes immediately use a new pool; old work finishes with temporary capacity overlap. Claude transport capacity remains deferred.
        </p>
        <section class="mt-4 rounded border p-3" aria-label="Routing Health">
          <h2 class="font-semibold">Routing Health</h2>
          <p :for={{field, {message, _}} <- @issues} role="alert">
            Configuration issue: {field} {message}
          </p>
          <p>
            Observed Provider availability comes only from probes. Pool contention does not change health.
          </p>
          <div :for={row <- @health} class="mt-3" id={"tier-#{row.tier}"}>
            <h3 class="font-semibold">{row.tier}: {row.model}</h3>
            <p>{row.status} · {row.transport}</p>
            <%= case row.occupancy do %>
              <% %{checked_out: occupied, capacity: capacity, queue_depth: queue} -> %>
                <p>
                  Checked-out connections: {occupied} / {capacity}; queued: {queue}; retiring pools: {row.retiring}
                </p>
              <% _ -> %>
                <p>Pool occupancy unavailable</p>
            <% end %>
          </div>
        </section>

        <div class="flex justify-between">
          <.button disabled={!@editing} class="mt-3 btn btn-primary" phx-disable-with="Saving…">
            Save
          </.button>
          <button
            type="button"
            disabled={!@editing or @selected.usage_count != 0}
            class="mt-3 btn btn-danger"
            phx-click="delete"
            phx-value-id={@selected.id}
            data-confirm="Are you sure you want to delete this service config?"
          >
            Delete
          </button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event(event, _, %{assigns: %{editing: false}} = socket)
      when event in ["save", "delete", "new"],
      do: {:noreply, put_flash(socket, :error, "Enable editing first")}

  def handle_event("test", _, %{assigns: %{testing: true}} = socket), do: {:noreply, socket}

  def handle_event("test", _, socket) do
    config = socket.assigns.selected

    {:noreply,
     socket
     |> assign(testing: true, test_results: "Testing…")
     |> start_async(:config_test, fn ->
       Administrative.generate(
         [%Oli.GenAI.Completions.Message{role: :user, content: "Reply with OK."}],
         [],
         config.primary_model,
         service_config: config,
         total_timeout_ms: 10_000,
         provider_opts: [max_tokens: 8]
       )
     end)}
  end

  def handle_event(event, _, %{assigns: %{testing: true}} = socket)
      when event in ["select", "save", "delete", "new"],
      do: {:noreply, put_flash(socket, :error, "Wait for the current test to finish")}

  def handle_event("select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = Enum.find(socket.assigns.service_configs, &(&1.id == id))

    {:noreply,
     socket
     |> assign(selected: selected)
     |> assign_form(Ecto.Changeset.change(selected))
     |> assign_health(selected)}
  end

  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Oli.Repo.get(ServiceConfig, id) do
      nil ->
        socket = put_flash(socket, :error, "Service Config not found")

        {:noreply,
         socket
         |> assign_form(ServiceConfig.changeset(socket.assigns.selected, %{}))
         |> assign_health(socket.assigns.selected)}

      item ->
        socket = clear_flash(socket)

        case GenAI.delete_service_config(item) do
          {:ok, _} ->
            all = all()
            selected = Enum.at(all, 0) || %ServiceConfig{}

            {:noreply,
             socket
             |> assign(editing: false, service_configs: all, selected: selected)
             |> assign_form(Ecto.Changeset.change(selected))
             |> assign_health(selected)}

          {:error, _reason} ->
            socket =
              put_flash(socket, :error, "Couldn't delete referenced service config")

            {:noreply,
             socket
             |> assign_form(ServiceConfig.changeset(socket.assigns.selected, %{}))
             |> assign_health(socket.assigns.selected)}
        end
    end
  end

  def handle_event("save", %{"service_config" => params}, socket) do
    params =
      Map.take(
        params,
        ~w(name primary_model_id secondary_model_id backup_model_id primary_pool_capacity secondary_pool_capacity backup_pool_capacity)
      )

    socket = clear_flash(socket)

    # refetch the selected model to ensure we have the latest state
    case Oli.Repo.get(ServiceConfig, socket.assigns.selected.id) do
      nil ->
        socket = put_flash(socket, :error, "Service config not found")

        {:noreply,
         socket
         |> assign_form(ServiceConfig.changeset(socket.assigns.selected, %{}))
         |> assign_health(socket.assigns.selected)}

      selected ->
        case GenAI.update_service_config(selected, params) do
          {:ok, service_config} ->
            all = all()
            selected = Enum.find(all, &(&1.id == service_config.id)) || service_config

            {:noreply,
             socket
             |> assign(service_configs: all, selected: selected, editing: false)
             |> assign_form(Ecto.Changeset.change(selected))
             |> assign_health(selected)}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket = put_flash(socket, :error, "Couldn't update service config")
            {:noreply, assign_form(socket, changeset)}
        end
    end
  end

  def handle_event("new", _, socket) do
    case GenAI.create_service_config(%{
           name: "New Service Config",
           primary_model_id:
             case Enum.find(GenAI.registered_models(), &(not is_nil(&1.provider_id))) do
               nil -> nil
               model -> model.id
             end,
           backup_model_id: nil
         }) do
      {:ok, service_config} ->
        all = all()
        selected = Enum.find(all, &(&1.id == service_config.id))
        changeset = Ecto.Changeset.change(selected)

        {:noreply,
         socket
         |> assign(selected: selected, service_configs: all)
         |> assign_form(changeset)
         |> assign_health(selected)}

      {:error, _changeset} ->
        # Handle error (e.g., show a flash message)
        Logger.warning("Failed to create service config")

        socket =
          socket
          |> put_flash(:error, "Failed to create new service config. Please try again.")
          |> assign(selected: %ServiceConfig{})

        {:noreply, socket}
    end
  end

  def handle_async(:config_test, {:ok, result}, socket),
    do: {:noreply, assign(socket, testing: false, test_results: Diagnostics.test_result(result))}

  def handle_async(:config_test, {:exit, _}, socket),
    do: {:noreply, assign(socket, testing: false, test_results: "Test failed: request_error")}

  def breadcrumb(),
    do: [
      Breadcrumb.new(%{
        link: ~p"/admin/gen_ai/service_configs",
        full_title: "Completions Service Configurations"
      })
    ]

  # Returns all registered models sorted by ID, which provides a stable sorting order
  def all do
    GenAI.service_configs()
  end

  def all_registered_models() do
    GenAI.registered_models()
    |> Enum.map(fn model ->
      {"#{model.name} (Provider ##{model.provider_id || "unassigned"})", model.id}
    end)
  end

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset, as: :service_config))
  end

  defp assign_health(socket, %ServiceConfig{id: nil}), do: assign(socket, health: [], issues: [])

  defp assign_health(socket, %ServiceConfig{} = selected) do
    assign(socket,
      health: health_for(selected),
      issues: Oli.GenAI.Configuration.audit_service_config(selected).errors
    )
  end

  defp assign_health(socket, _), do: assign(socket, health: [], issues: [])

  defp health_for(config), do: Diagnostics.tiers(config, Diagnostics.snapshot())

  defp schedule_health_refresh(socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh_health, @health_refresh_ms)
    end

    socket
  end

  def handle_info(:refresh_health, socket) do
    socket =
      socket
      |> assign_health(socket.assigns.selected)
      |> schedule_health_refresh()

    {:noreply, socket}
  end
end
