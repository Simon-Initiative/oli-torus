defmodule OliWeb.GenAI.ServiceConfigsView do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{ServiceConfig}
  alias OliWeb.Common.Breadcrumb

  @form_control_classes "block w-full p-2.5
  text-sm text-gray-900 bg-gray-50
  rounded-lg border border-gray-300
  focus:ring-blue-500 focus:border-blue-500
  dark:bg-gray-700 dark:border-gray-600
  dark:placeholder-gray-400 dark:text-white"

  def mount(_, _session, socket) do
    all = all()
    selected = Enum.at(all, 0)
    changeset = ServiceConfig.changeset(selected, %{})

    registered_models = all_registered_models()

    {:ok,
     assign(socket,
       editing: false,
       form: to_form(changeset),
       changeset: changeset,
       selected: selected,
       service_configs: all,
       registered_models: registered_models,
       breadcrumbs: breadcrumb()
     )}
  end

  attr :service_configs, :list, required: true
  attr :registered_models, :list, required: true
  attr(:selected, ServiceConfig)
  attr :breadcrumbs, :any
  attr :changeset, :any
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
          changeset={@changeset}
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
          <%= @service_config.name %>
        </h3>
        <div class="flex">
          <div class="mr-5">
            <span class="text-gray-800 text-xs py-0.5">Primary: </span>
            <span class="text-gray-800 text-xs font-mono py-0.5 ">
              <%= @service_config.primary_model.name %>
            </span>
          </div>
          <div>
            <span class="text-gray-800 text-xs py-0.5">Backup: </span>
            <span class="text-gray-800 text-xs font-mono py-0.5">
              <%= if is_nil(@service_config.backup_model) do
                "None"
              else
                @service_config.backup_model.name
              end %>
            </span>
          </div>
        </div>
      </div>
      <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
        <%= if @service_config.usage_count > 0 do %>
          <p class="mt-0 text-xs text-gray-500">
            Used by <strong><%= @service_config.usage_count %></strong> feature config(s)
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
  attr :changeset, :any
  attr :editing, :boolean, default: false
  attr :registered_models, :list, required: true

  def selected_item(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="basis-1/2 p-4">
      <.form :let={f} for={@changeset} id="service-config-form" phx-submit="save">
        <.input
          field={f[:name]}
          label="Friendly Name"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:primary_model_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={@registered_models}
          label="Primary Registered Model"
        />
        <.input
          field={f[:backup_model_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={[{"No backup", nil} | @registered_models]}
          label="Backup Registered Model"
        />

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
     assign(socket, selected: selected, changeset: ServiceConfig.changeset(selected, %{}))}
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
         assign(socket, changeset: ServiceConfig.changeset(socket.assigns.selected, %{}))}

      item ->
        socket = clear_flash(socket)

        case GenAI.delete_service_config(item) do
          {:ok, _} ->
            all = all()
            selected = Enum.at(all, 0)

            {:noreply,
             assign(socket,
               editing: false,
               service_configs: all,
               selected: selected,
               changeset: ServiceConfig.changeset(selected, %{})
             )}

          {:error, reason} ->
            socket =
              put_flash(socket, :error, "Couldn't delete service config: #{inspect(reason)}")

            {:noreply,
             assign(socket, changeset: ServiceConfig.changeset(socket.assigns.selected, %{}))}
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
         assign(socket, changeset: ServiceConfig.changeset(socket.assigns.selected, %{}))}

      selected ->
        case GenAI.update_service_config(selected, params) do
          {:ok, service_config} ->
            all = all()

            {:noreply,
             assign(socket,
               service_configs: all,
               selected: service_config,
               editing: false,
               changeset: ServiceConfig.changeset(service_config, %{})
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket = put_flash(socket, :error, "Couldn't update service config")
            {:noreply, assign(socket, changeset: changeset)}
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

        {:noreply, assign(socket, selected: selected, service_configs: all, changeset: changeset)}

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
end
