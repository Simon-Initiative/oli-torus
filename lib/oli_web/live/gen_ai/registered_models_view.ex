defmodule OliWeb.GenAI.RegisteredModelsView do
  use OliWeb, :live_view
  on_mount OliWeb.GenAI.AdminMount
  alias Oli.GenAI
  alias Oli.GenAI.{Administrative, Diagnostics}
  alias Oli.GenAI.Completions.{RegisteredModel, Message}

  @doc "Loads model inference settings; credentials and capacity belong to Providers and ServiceConfigs."
  def mount(_, _, socket) do
    models = GenAI.registered_models()
    model = List.first(models) || %RegisteredModel{}

    {:ok,
     socket
     |> assign(
       registered_models: models,
       providers: GenAI.providers(),
       selected: model,
       editing: false,
       testing: false,
       test_results: "",
       breadcrumbs: []
     )
     |> form(model)}
  end

  @doc "Renders model selection, inference timeouts, capabilities and the probe designation flag."
  def render(assigns) do
    ~H"""
    <main class="space-y-4 p-4">
      <h1 class="text-xl font-semibold">Registered LLM Models</h1>
      <nav class="flex gap-4" aria-label="GenAI administration">
        <.link navigate={~p"/admin/gen_ai/providers"}>Providers and health</.link>
        <.link navigate={~p"/admin/gen_ai/service_configs"}>
          Service configurations and capacity
        </.link>
      </nav>
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
      <ul aria-label="Registered models" class="space-y-2">
        <li :for={model <- @registered_models}>
          <button
            type="button"
            phx-click="select_model"
            phx-value-id={model.id}
            aria-pressed={to_string(@selected.id == model.id)}
            class="rounded border px-3 py-2"
          >
            {model.name} ({model.model})
          </button>
          <span :if={model.health_check}>Health-check candidate</span>
        </li>
      </ul>
      <button
        type="button"
        phx-click="new_model"
        disabled={!@editing}
        class="rounded border px-3 py-2"
      >
        New Model
      </button>
      <p>
        When several models are flagged, the lowest ID is selected. With no flag, the lowest-ID model is automatically designated.
      </p>
      <p>
        Provider credentials are managed on the Providers page. Claude inference requires a managed transport implementation and is currently unsupported.
      </p>
      <button
        type="button"
        phx-click="test"
        disabled={@testing or is_nil(@selected.id)}
        class="rounded border px-3 py-2"
      >
        Test Model
      </button>
      <p role="status" aria-live="polite">{@test_results}</p>
      <.form for={@form} id="registered-model-form" phx-submit="save" class="max-w-2xl space-y-3">
        <.input field={@form[:name]} label="Friendly Name" disabled={!@editing} />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:provider_id]}
          type="select"
          label="Configured Provider"
          prompt="Select a Provider"
          options={Enum.map(@providers, &{&1.name, &1.id})}
          disabled={!@editing}
        />
        <.input field={@form[:model]} label="Model" disabled={!@editing} />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:health_check]}
          type="checkbox"
          label="Health-check candidate"
          disabled={!@editing}
        />
        <label for="model-capabilities" class="block">Capabilities (comma-separated)</label>
        <input
          id="model-capabilities"
          name="registered_model[capabilities_text]"
          value={Enum.join(@form[:capabilities].value || [], ", ")}
          disabled={!@editing}
          class="w-full rounded border p-2"
        />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:timeout]}
          type="number"
          min="1"
          label="Connection establishment timeout (ms)"
          disabled={!@editing}
        />
        <.input
          class="block w-full rounded border border-gray-300 bg-white p-2 text-gray-900 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
          field={@form[:recv_timeout]}
          type="number"
          min="1"
          label="Response inactivity timeout (ms)"
          disabled={!@editing}
        />
        <button type="submit" disabled={!@editing} class="rounded bg-blue-700 px-4 py-2 text-white">
          Save
        </button>
        <button
          type="button"
          phx-click="delete"
          disabled={!@editing or is_nil(@selected.id) or (@selected.service_config_count || 0) > 0}
          data-confirm="Delete this unreferenced model?"
          class="rounded border px-4 py-2"
        >
          Delete
        </button>
      </.form>
    </main>
    """
  end

  def handle_event("toggle_editing", _, socket),
    do: {:noreply, assign(socket, editing: !socket.assigns.editing)}

  def handle_event(event, _, %{assigns: %{editing: false}} = socket)
      when event in ["save", "delete", "new_model"],
      do: {:noreply, put_flash(socket, :error, "Enable editing first")}

  def handle_event(event, _, %{assigns: %{testing: true}} = socket)
      when event in ["select_model", "new_model", "save", "delete"],
      do: {:noreply, put_flash(socket, :error, "Wait for the current test to finish")}

  def handle_event("select_model", %{"id" => id}, socket) do
    case Enum.find(GenAI.registered_models(), &(to_string(&1.id) == id)) do
      nil -> {:noreply, put_flash(socket, :error, "Model not found")}
      model -> {:noreply, socket |> assign(selected: model, test_results: "") |> form(model)}
    end
  end

  def handle_event("new_model", _, socket),
    do: {:noreply, socket |> assign(selected: %RegisteredModel{}) |> form(%RegisteredModel{})}

  def handle_event("save", %{"registered_model" => params}, socket) do
    attrs = Map.take(params, ~w(name provider_id model health_check timeout recv_timeout))

    attrs =
      Map.put(
        attrs,
        "capabilities",
        String.split(params["capabilities_text"] || "", ",", trim: true)
        |> Enum.map(&String.trim/1)
      )

    # The adapter comes from the configured Provider, never from a forged form field.
    provider = Enum.find(GenAI.providers(), &(to_string(&1.id) == attrs["provider_id"]))

    result =
      case provider do
        nil ->
          {:error, :missing_provider}

        _provider ->
          case socket.assigns.selected.id do
            nil -> GenAI.create_registered_model(attrs)
            _ -> GenAI.update_registered_model(socket.assigns.selected, attrs)
          end
      end

    case result do
      {:ok, model} ->
        {:noreply,
         socket
         |> assign(registered_models: GenAI.registered_models(), selected: model, editing: false)
         |> form(model)
         |> put_flash(:info, "Model saved")}

      {:error, %Ecto.Changeset{data: %Oli.GenAI.Completions.ServiceConfig{} = config} = cs} ->
        details =
          Enum.map_join(cs.errors, "; ", fn {field, {message, _}} -> "#{field}: #{message}" end)

        message = "Would invalidate ServiceConfig ##{config.id} (#{config.name}): #{details}"

        model_cs =
          RegisteredModel.changeset(socket.assigns.selected, attrs)
          |> Ecto.Changeset.add_error(:provider_id, message)
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(form: to_form(model_cs, as: :registered_model))
         |> put_flash(:error, message)}

      {:error, %Ecto.Changeset{data: %RegisteredModel{}} = cs} ->
        {:noreply, assign(socket, form: to_form(cs, as: :registered_model))}

      _ ->
        {:noreply, put_flash(socket, :error, "Model could not be saved; select a valid Provider")}
    end
  end

  def handle_event("delete", _, socket) do
    case GenAI.delete_registered_model(socket.assigns.selected) do
      {:ok, _} ->
        models = GenAI.registered_models()
        model = List.first(models) || %RegisteredModel{}

        {:noreply,
         socket
         |> assign(registered_models: models, selected: model, editing: false)
         |> form(model)}

      _ ->
        {:noreply, put_flash(socket, :error, "Model is referenced or could not be deleted")}
    end
  end

  def handle_event("test", _, %{assigns: %{testing: true}} = socket), do: {:noreply, socket}

  def handle_event("test", _, socket) do
    model = socket.assigns.selected

    {:noreply,
     socket
     |> assign(testing: true, test_results: "Testing…")
     |> start_async(:model_test, fn ->
       Administrative.generate(
         [%Message{role: :user, content: "Describe the sun in one word."}],
         [],
         model,
         total_timeout_ms: 10_000,
         provider_opts: [max_tokens: 8]
       )
     end)}
  end

  def handle_async(:model_test, {:ok, result}, socket),
    do: {:noreply, assign(socket, testing: false, test_results: Diagnostics.test_result(result))}

  def handle_async(:model_test, {:exit, _}, socket),
    do: {:noreply, assign(socket, testing: false, test_results: "Test failed: request_error")}

  defp form(socket, model),
    do: assign(socket, form: to_form(Ecto.Changeset.change(model), as: :registered_model))
end
