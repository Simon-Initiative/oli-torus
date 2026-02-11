defmodule OliWeb.GenAI.ServiceConfigsView do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{ServiceConfig}
  alias Oli.GenAI.AdmissionControl
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
    selected = Enum.at(all, 0)
    changeset = ServiceConfig.changeset(selected, %{})

    registered_models = all_registered_models()

    socket =
      socket
      |> assign(editing: false)
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
      <div class="flex">
        <div class="flex flex-col basis-1/2">
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
    <li
      phx-click="select"
      phx-value-id={@service_config.id}
      aria-selected={@selected.id == @service_config.id}
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
              {@service_config.primary_model.name}
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
    </li>
    """
  end

  attr(:selected, ServiceConfig)
  attr :form, :any
  attr :health, :map, default: nil
  attr :editing, :boolean, default: false
  attr :registered_models, :list, required: true

  def selected_item(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="basis-1/2 p-4">
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

        <%= if @health do %>
          <div class="mt-6 border-t border-gray-200 pt-4">
            <h3 class="text-sm font-semibold text-gray-900">Routing Health</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-3 text-sm text-gray-700">
              <div>
                <div class="text-xs uppercase text-gray-500">Primary Breaker</div>
                <div>{@health.primary.state}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Secondary Breaker</div>
                <div>{@health.secondary.state}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Backup Breaker</div>
                <div>{@health.backup.state}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Error Rate</div>
                <div>{format_rate(@health.primary.error_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Secondary Error Rate</div>
                <div>{format_rate(@health.secondary.error_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">429 Rate</div>
                <div>{format_rate(@health.primary.rate_limit_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Secondary 429 Rate</div>
                <div>{format_rate(@health.secondary.rate_limit_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Latency p95 (ms)</div>
                <div>{@health.primary.latency_p95_ms}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Secondary Latency p95 (ms)</div>
                <div>{@health.secondary.latency_p95_ms}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Last Reason</div>
                <div>{@health.primary.last_reason}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Secondary Last Reason</div>
                <div>{@health.secondary.last_reason}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Backup Error Rate</div>
                <div>{format_rate(@health.backup.error_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Backup 429 Rate</div>
                <div>{format_rate(@health.backup.rate_limit_rate)}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Backup Latency p95 (ms)</div>
                <div>{@health.backup.latency_p95_ms}</div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Backup Last Reason</div>
                <div>{@health.backup.last_reason}</div>
              </div>
            </div>
          </div>
        <% end %>

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

  def handle_event("select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = Enum.find(socket.assigns.service_configs, &(&1.id == id))

    {:noreply,
     socket
     |> assign(selected: selected)
     |> assign_form(ServiceConfig.changeset(selected, %{}))
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
            selected = Enum.at(all, 0)

            {:noreply,
             socket
             |> assign(editing: false, service_configs: all, selected: selected)
             |> assign_form(ServiceConfig.changeset(selected, %{}))
             |> assign_health(selected)}

          {:error, reason} ->
            socket =
              put_flash(socket, :error, "Couldn't delete service config: #{inspect(reason)}")

            {:noreply,
             socket
             |> assign_form(ServiceConfig.changeset(socket.assigns.selected, %{}))
             |> assign_health(socket.assigns.selected)}
        end
    end
  end

  def handle_event("save", %{"service_config" => params}, socket) do
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
             |> assign_form(ServiceConfig.changeset(selected, %{}))
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
           primary_model_id: socket.assigns.registered_models |> List.first() |> elem(1),
           backup_model_id: nil
         }) do
      {:ok, service_config} ->
        all = all()
        selected = Enum.find(all, &(&1.id == service_config.id))
        changeset = ServiceConfig.changeset(selected, %{})

        {:noreply,
         socket
         |> assign(selected: selected, service_configs: all)
         |> assign_form(changeset)
         |> assign_health(selected)}

      {:error, changeset} ->
        # Handle error (e.g., show a flash message)
        Logger.error("Failed to create new service config: #{inspect(changeset)}")

        socket =
          socket
          |> put_flash(:error, "Failed to create new service config. Please try again.")
          |> assign(selected: nil)

        {:noreply, socket}
    end
  end

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
      {model.name, model.id}
    end)
  end

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset, as: :service_config))
  end

  defp assign_health(socket, %ServiceConfig{} = selected) do
    assign(socket, health: health_for(selected))
  end

  defp assign_health(socket, _), do: assign(socket, health: nil)

  defp health_for(%ServiceConfig{} = service_config) do
    default_snapshot = %{
      state: :closed,
      error_rate: 0.0,
      rate_limit_rate: 0.0,
      latency_p95_ms: 0,
      last_reason: :none
    }

    primary =
      if service_config.primary_model do
        default_snapshot
        |> Map.merge(AdmissionControl.get_breaker_snapshot(service_config.primary_model.id))
      else
        %{default_snapshot | state: :unknown}
      end

    secondary =
      if service_config.secondary_model do
        default_snapshot
        |> Map.merge(AdmissionControl.get_breaker_snapshot(service_config.secondary_model.id))
      else
        %{default_snapshot | state: :none}
      end

    backup =
      if service_config.backup_model do
        default_snapshot
        |> Map.merge(AdmissionControl.get_breaker_snapshot(service_config.backup_model.id))
      else
        %{default_snapshot | state: :none}
      end

    %{
      primary: primary,
      secondary: secondary,
      backup: backup
    }
  end

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

  defp format_rate(rate) when is_float(rate), do: "#{Float.round(rate * 100, 1)}%"
  defp format_rate(_), do: "0%"
end
