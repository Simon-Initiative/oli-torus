defmodule OliWeb.GenAI.RegisteredModelsView do
  use OliWeb, :live_view

  require Logger

  alias Oli.GenAI.Completions
  alias Oli.GenAI
  alias Oli.GenAI.Completions.{RegisteredModel, Message}
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
    changeset = RegisteredModel.changeset(selected, %{})

    {:ok,
     assign(socket,
       editing: false,
       test_results: "",
       form: to_form(changeset),
       changeset: changeset,
       selected: selected,
       registered_models: all,
       breadcrumbs: breadcrumb()
     )}
  end

  attr :registered_models, :list, required: true
  attr(:selected, RegisteredModel)
  attr :breadcrumbs, :any
  attr :changeset, :any
  attr :title, :string, default: "Registered LLM Models"
  attr :editing, :boolean, default: false
  attr :test_results, :string, default: ""

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
            <%= for registered_model <- @registered_models do %>
              <.registered_model registered_model={registered_model} selected={@selected} />
            <% end %>
          </ul>
          <div>
            <button disabled={!@editing} class="btn btn-primary btn-sm" phx-click="new_model">
              + New Model
            </button>
          </div>
        </div>

        <.selected_item
          selected={@selected}
          changeset={@changeset}
          editing={@editing}
          test_results={@test_results}
        />
      </div>
    </div>
    """
  end

  attr(:registered_model, RegisteredModel)
  attr(:selected, RegisteredModel)

  def registered_model(assigns) do
    ~H"""
    <li
      phx-click="select_model"
      phx-value-id={@registered_model.id}
      aria-selected={@selected.id == @registered_model.id}
      class={
        [
          # base
          "flex justify-between gap-x-6 py-1 px-2 rounded-md cursor-pointer transition-colors bg-white dark:bg-gray-900 dark:text-gray-100",

          # selected (non-hover)
          @selected.id == @registered_model.id && "bg-indigo-50 dark:bg-gray-700 ",

          # hover (overrides both unselected and selected)
          "hover:bg-indigo-100 dark:hover:bg-gray-600"
        ]
      }
    >
      <div class="flex flex-col min-w-0 gap-x-4">
        <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
          {@registered_model.name}
        </h3>
        <div class="text-gray-800 text-xs font-mono py-0.5">
          {@registered_model.provider}: {@registered_model.url_template}
        </div>
      </div>
      <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
        <p class="mt-0 text-xs text-gray-500">model: {@registered_model.model}</p>

        <%= if @registered_model.service_config_count > 0 do %>
          <p class="mt-0 text-xs text-gray-500">
            Used by <strong>{@registered_model.service_config_count}</strong> service config(s)
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

  attr(:selected, RegisteredModel)
  attr :changeset, :any
  attr :editing, :boolean, default: false
  attr :test_results, :string, default: ""

  def selected_item(assigns) do
    assigns =
      assigns
      |> assign_new(:form_control_classes, fn -> @form_control_classes end)

    ~H"""
    <div class="basis-1/2 p-4">
      <div class="flex">
        <button
          title="Test the selected model by asking it to describe the sun in one word"
          class="btn btn-secondary btn-sm mb-2 mr-3"
          phx-disable-with="Testing..."
          phx-click="test"
        >
          Test Model
        </button>
        <div>{@test_results}</div>
      </div>

      <.form :let={f} for={@changeset} id="registered-model-form" phx-submit="save">
        <.input
          field={f[:name]}
          label="Friendly Name"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:provider]}
          type="select"
          disabled={!@editing}
          class={@form_control_classes}
          options={[
            {"OpenAI Compliant", :open_ai},
            {"Anthropic Claude 3.x", :claude},
            {"Null", :null}
          ]}
          label="Provider"
        />
        <.input field={f[:model]} label="Model" disabled={!@editing} class={@form_control_classes} />
        <.input
          field={f[:url_template]}
          label="URL Template"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:api_key]}
          type="password"
          label="API Key"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:secondary_api_key]}
          type="password"
          label="Secondary API Key"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:timeout]}
          type="number"
          label="Timeout (ms)"
          disabled={!@editing}
          class={@form_control_classes}
        />
        <.input
          field={f[:recv_timeout]}
          type="number"
          label="Recv Timeout (ms)"
          disabled={!@editing}
          class={@form_control_classes}
        />

        <div class="flex justify-between">
          <.button disabled={!@editing} class="mt-3 btn btn-primary" phx-disable-with="Saving…">
            Save
          </.button>
          <button
            type="button"
            disabled={!@editing or @selected.service_config_count != 0}
            class="mt-3 btn btn-danger"
            phx-click="delete"
            phx-value-id={@selected.id}
            data-confirm="Are you sure you want to delete this registered model?"
          >
            Delete
          </button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("select_model", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = Enum.find(socket.assigns.registered_models, &(&1.id == id))

    {:noreply,
     assign(socket, selected: selected, changeset: RegisteredModel.changeset(selected, %{}))}
  end

  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  def handle_event("test", _, socket) do
    case Completions.generate(
           [%Message{role: :user, content: "Give me one word describing the sun"}],
           [],
           socket.assigns.selected
         ) do
      {:ok, response} ->
        test_results = "Test successful: #{response}"

        {:noreply, assign(socket, test_results: test_results)}

      {:error, reason} ->
        test_results = "Test failed: #{inspect(reason)}"
        {:noreply, assign(socket, test_results: test_results)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Oli.Repo.get(RegisteredModel, id) do
      nil ->
        socket = put_flash(socket, :error, "Registered model not found")

        {:noreply,
         assign(socket, changeset: RegisteredModel.changeset(socket.assigns.selected, %{}))}

      item ->
        socket = clear_flash(socket)

        case GenAI.delete_registered_model(item) do
          {:ok, _} ->
            all = all()
            selected = Enum.at(all, 0)

            {:noreply,
             assign(socket,
               editing: false,
               registered_models: all,
               selected: selected,
               changeset: RegisteredModel.changeset(selected, %{})
             )}

          {:error, reason} ->
            socket =
              put_flash(socket, :error, "Couldn't delete registered model: #{inspect(reason)}")

            {:noreply,
             assign(socket, changeset: RegisteredModel.changeset(socket.assigns.selected, %{}))}
        end
    end
  end

  def handle_event("save", %{"registered_model" => params}, socket) do
    socket = clear_flash(socket)

    # refetch the selected model to ensure we have the latest state
    case Oli.Repo.get(RegisteredModel, socket.assigns.selected.id) do
      nil ->
        socket = put_flash(socket, :error, "Registered model not found")

        {:noreply,
         assign(socket, changeset: RegisteredModel.changeset(socket.assigns.selected, %{}))}

      selected ->
        case GenAI.update_registered_model(selected, params) do
          {:ok, registered_model} ->
            all = all()

            {:noreply,
             assign(socket,
               registered_models: all,
               selected: registered_model,
               editing: false,
               changeset: RegisteredModel.changeset(registered_model, %{})
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket = put_flash(socket, :error, "Couldn't update registered model")
            {:noreply, assign(socket, changeset: changeset)}
        end
    end
  end

  def handle_event("new_model", _, socket) do
    case GenAI.create_registered_model(%{
           name: "New Model",
           provider: :open_ai,
           model: "model-name",
           url_template: "https://api.openai.com",
           api_key: "dummy",
           secondary_api_key: "dummy",
           timeout: 8000,
           recv_timeout: 60000
         }) do
      {:ok, registered_model} ->
        all = all()
        selected = Enum.find(all, &(&1.id == registered_model.id))
        changeset = RegisteredModel.changeset(selected, %{})

        {:noreply,
         assign(socket, selected: selected, registered_models: all, changeset: changeset)}

      {:error, changeset} ->
        # Handle error (e.g., show a flash message)
        Logger.error("Failed to create new registered model: #{inspect(changeset)}")

        socket =
          socket
          |> put_flash(:error, "Failed to create new registered model. Please try again.")
          |> assign(selected: nil)

        {:noreply, socket}
    end
  end

  def breadcrumb(),
    do: [
      Breadcrumb.new(%{
        link: ~p"/admin/gen_ai/registered_models",
        full_title: "Registered LLM Models"
      })
    ]

  # Returns all registered models sorted by ID, which provides a stable sorting order
  def all do
    GenAI.registered_models()
  end
end
