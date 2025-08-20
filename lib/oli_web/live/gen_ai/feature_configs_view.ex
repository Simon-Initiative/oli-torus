defmodule OliWeb.GenAI.FeatureConfigsView do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI
  alias OliWeb.Common.Breadcrumb
  alias Oli.GenAI.FeatureConfig
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections

  @form_control_classes "block w-full p-2.5
  text-sm text-gray-900 bg-gray-50
  rounded-lg border border-gray-300
  focus:ring-blue-500 focus:border-blue-500
  dark:bg-gray-700 dark:border-gray-600
  dark:placeholder-gray-400 dark:text-white"

  @impl true
  def mount(_, _session, socket) do
    all = all(true)
    selected = Enum.at(all, 0)
    changeset = FeatureConfig.changeset(selected, %{})

    service_configs = all_service_configs()

    {:ok,
     assign(socket,
       show_defaults_only?: true,
       editing: false,
       section_slug: "",
       section: nil,
       form: to_form(changeset),
       changeset: changeset,
       selected: selected,
       service_configs: service_configs,
       selected_service_config: Enum.at(service_configs, 0),
       selected_feature: :student_dialogue,
       feature_configs: all,
       breadcrumbs: breadcrumb()
     )}
  end

  attr :show_defaults_only?, :boolean, required: true
  attr :service_configs, :list, required: true
  attr :feature_configs, :list, required: true
  attr(:selected, FeatureConfig)
  attr :breadcrumbs, :any
  attr :changeset, :any
  attr :title, :string, default: "GenAI Feature Configurations"
  attr :editing, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex">
        <div class="flex basis-1/2 justify-end">
          <div>Show Defaults Only</div>
          <.toggle_switch
            id="toggle_defaults"
            class="ml-4"
            checked={@show_defaults_only?}
            on_toggle="toggle_defaults"
            name="toggle_defaults"
          />
        </div>
        <div class="flex basis-1/2 justify-end">
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
          <h3 class="text-lg font-semibold mb-2">Existing Feature Configs</h3>
          <ul role="list" class="divide-y divide-gray-100">
            <%= for feature_config <- @feature_configs do %>
              <.feature_config feature_config={feature_config} selected={@selected} />
            <% end %>
          </ul>
          <div class="m-4">
            <.create_new
              service_configs={@service_configs}
              section_slug={@section_slug}
              section={@section}
              editing={@editing}
            />
          </div>
        </div>
        <div class="basis-1/2">
          <.selected_item
            service_configs={@service_configs}
            selected={@selected}
            changeset={@changeset}
            editing={@editing}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:feature_config, FeatureConfig)
  attr(:selected, FeatureConfig)

  def feature_config(assigns) do
    ~H"""
    <li
      phx-click="select"
      phx-value-id={@feature_config.id}
      aria-selected={@selected.id == @feature_config.id}
      class={
        [
          # base
          "flex justify-between gap-x-6 py-1 px-2 rounded-md cursor-pointer transition-colors bg-white dark:bg-gray-900 dark:text-gray-100",

          # selected (non-hover)
          @selected.id == @feature_config.id && "bg-indigo-50 dark:bg-gray-700 ",

          # hover (overrides both unselected and selected)
          "hover:bg-indigo-100 dark:hover:bg-gray-600"
        ]
      }
    >
      <div class="flex flex-col min-w-0 gap-x-4">
        <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
          {@feature_config.feature}
        </h3>
        <div class="flex">
          <%= if is_nil(@feature_config.section) do %>
            <span class="text-sm text-gray-500">DEFAULT</span>
          <% else %>
            <span class="text-sm text-gray-500">
              {@feature_config.section.slug}
            </span>
          <% end %>
        </div>
      </div>
      <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
        <div>
          Service Config: {@feature_config.service_config.name}
        </div>
      </div>
    </li>
    """
  end

  attr :service_configs, :list, required: true
  attr :section_slug, :string, required: true
  attr :section, Section
  attr :editing, :boolean, default: false

  def create_new(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="flex flex-col mt-4">
      <h3 class="text-lg font-semibold mb-2">Create New Feature Config</h3>

      <div>
        <label for="feature" class="block text-sm font-medium text-gray-700">Feature</label>
        <select phx-hook="SelectListener" id="feature" name="feature" class={@form_control_classes}>
          <option value="student_dialogue">Student Dialogue</option>
          <option value="instructor_dashboard">Instructor Dashboard</option>
        </select>
      </div>

      <div>
        <label for="service_config" class="block text-sm font-medium text-gray-700">
          Service Config
        </label>
        <select id="service_config" name="service_config_id" class={@form_control_classes}>
          <%= for {name, id} <- @service_configs do %>
            <option value={id}>{name}</option>
          <% end %>
        </select>
      </div>

      <div class="mt-3">
        <div><small>Paste or type in the section or product slug</small></div>
        <input
          id="slug"
          phx-hook="DebouncedTextInputListener"
          type="text"
          placeholder="Section Slug"
          value={@section_slug}
          class={@form_control_classes}
          disabled={!@editing}
        />
      </div>

      <%= if @section do %>
        <div class="mt-2 bg-slate-200 p-2 rounded-md">
          <div class="text-sm text-gray-800">{@section.title}</div>
          <div class="text-sm text-gray-500">
            {if @section.type == :enrollable do
              "Section"
            else
              "Product"
            end}
          </div>
        </div>
      <% end %>

      <button phx-click="new" class="btn btn-primary mt-4" disabled={!@editing or is_nil(@section)}>
        Create
      </button>
    </div>
    """
  end

  attr(:selected, FeatureConfig)
  attr :changeset, :any
  attr :editing, :boolean, default: false
  attr :service_configs, :list, required: true

  def selected_item(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="basis-1/2 p-4">
      <h3 class="text-lg font-semibold mb-2">Edit Selected Feature Config</h3>

      <.form :let={f} for={@changeset} id="feature-config-form" phx-submit="save">
        <.input
          field={f[:feature]}
          type="select"
          disabled={true}
          class={@form_control_classes}
          options={[
            {"Student Dialogue", :student_dialogue},
            {"Instructor Dashboard", :instructor_dashboard}
          ]}
          label="Feature"
        />
        <.input
          field={f[:section_id]}
          type="text"
          disabled={true}
          class={@form_control_classes}
          value={if is_nil(@selected.section), do: "", else: @selected.section.slug}
          label="Section Slug"
        />

        <.input
          field={f[:service_config_id]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={@service_configs}
          label="Service Configs"
        />

        <div class="flex justify-between">
          <.button disabled={!@editing} class="mt-3 btn btn-primary" phx-disable-with="Saving…">
            Save
          </.button>
          <button
            type="button"
            disabled={!@editing or is_nil(@selected.section_id)}
            class="mt-3 btn btn-danger"
            phx-click="delete"
            phx-value-id={@selected.id}
            data-confirm="Are you sure you want to delete this feature config?"
          >
            Delete
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("change", %{"id" => "slug", "value" => slug}, socket) do
    case Sections.get_section_by_slug(slug) do
      nil -> {:noreply, assign(socket, section_slug: slug, section: nil)}
      section -> {:noreply, assign(socket, section_slug: slug, section: section)}
    end
  end

  def handle_event("save", %{"feature_config" => params}, socket) do
    socket = clear_flash(socket)

    # refetch the selected model to ensure we have the latest state
    case Oli.Repo.get(FeatureConfig, socket.assigns.selected.id) do
      nil ->
        socket = put_flash(socket, :error, "Feature config not found")

        {:noreply,
         assign(socket, changeset: FeatureConfig.changeset(socket.assigns.selected, %{}))}

      selected ->
        case GenAI.update_feature_config(selected, params) do
          {:ok, feature_config} ->
            all = all(socket.assigns.show_defaults_only?)

            feature_config = Oli.Repo.preload(feature_config, [:service_config, :section])

            {:noreply,
             assign(socket,
               feature_configs: all,
               selected: feature_config,
               editing: false,
               changeset: FeatureConfig.changeset(feature_config, %{})
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket = put_flash(socket, :error, "Couldn't update feature config")
            {:noreply, assign(socket, changeset: changeset)}
        end
    end
  end

  def handle_event("select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = Enum.find(socket.assigns.feature_configs, &(&1.id == id))

    {:noreply,
     assign(socket, selected: selected, changeset: FeatureConfig.changeset(selected, %{}))}
  end

  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  def handle_event("toggle_defaults", _, socket) do
    new_value = !socket.assigns.show_defaults_only?

    all = all(new_value)
    selected = Enum.at(all, 0)
    changeset = FeatureConfig.changeset(selected, %{})

    {:noreply,
     assign(socket,
       feature_configs: all,
       selected: selected,
       changeset: changeset,
       show_defaults_only?: new_value
     )}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Oli.Repo.get(FeatureConfig, id) do
      nil ->
        socket = put_flash(socket, :error, "Feature Config not found")

        {:noreply,
         assign(socket, changeset: FeatureConfig.changeset(socket.assigns.selected, %{}))}

      item ->
        socket = clear_flash(socket)

        case GenAI.delete_feature_config(item) do
          {:ok, _} ->
            all = all(socket.assigns.show_defaults_only?)
            selected = Enum.at(all, 0)

            {:noreply,
             assign(socket,
               editing: false,
               feature_configs: all,
               selected: selected,
               changeset: FeatureConfig.changeset(selected, %{})
             )}

          {:error, reason} ->
            socket =
              put_flash(socket, :error, "Couldn't delete feature config: #{inspect(reason)}")

            {:noreply,
             assign(socket, changeset: FeatureConfig.changeset(socket.assigns.selected, %{}))}
        end
    end
  end

  def handle_event("new", _, socket) do
    feature = socket.assigns.selected_feature

    case GenAI.feature_config_exists?(feature, socket.assigns.section.id) do
      true ->
        socket =
          put_flash(
            socket,
            :error,
            "Feature config for #{feature} already exists for this section."
          )

        {:noreply, socket}

      false ->
        create_feature_config(feature, socket)
    end
  end

  def handle_event("change", %{"id" => "feature", "value" => feature}, socket) do
    {:noreply, assign(socket, selected_feature: String.to_existing_atom(feature))}
  end

  defp create_feature_config(feature, socket) do
    case GenAI.create_feature_config(%{
           feature: feature,
           service_config_id: socket.assigns.selected_service_config |> elem(1),
           section_id: socket.assigns.section.id
         }) do
      {:ok, feature_config} ->
        all = all(socket.assigns.show_defaults_only?)
        selected = Enum.find(all, &(&1.id == feature_config.id))
        changeset = FeatureConfig.changeset(selected, %{})

        {:noreply, assign(socket, selected: selected, feature_configs: all, changeset: changeset)}

      {:error, changeset} ->
        # Handle error (e.g., show a flash message)
        Logger.error("Failed to create new feature config: #{inspect(changeset)}")

        socket =
          socket
          |> put_flash(:error, "Failed to create new feature config. Please try again.")
          |> assign(selected: nil)

        {:noreply, socket}
    end
  end

  def breadcrumb(),
    do: [
      Breadcrumb.new(%{
        link: ~p"/admin/gen_ai/feature_configs",
        full_title: "GenAI Feature Configurations"
      })
    ]

  def all(show_defaults_only?) do
    GenAI.feature_configs()
    |> Enum.filter(fn fc ->
      if show_defaults_only? do
        is_nil(fc.section_id)
      else
        true
      end
    end)
  end

  def all_service_configs() do
    GenAI.service_configs()
    |> Enum.map(fn sc ->
      {sc.name, sc.id}
    end)
  end
end
