defmodule OliWeb.GenAI.RegisteredModelsView do
  use OliWeb, :live_view
  on_mount OliWeb.GenAI.AdminMount
  alias Oli.GenAI
  alias Oli.GenAI.{Administrative, Diagnostics}
  alias Oli.GenAI.Completions.{RegisteredModel, Message}
  alias OliWeb.GenAI.AdminComponents
  alias OliWeb.Common.Breadcrumb

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
       breadcrumbs: [
         Breadcrumb.new(%{
           link: ~p"/admin/gen_ai/registered_models",
           full_title: "Registered LLM Models"
         })
       ]
     )
     |> form(model)}
  end

  @doc "Renders model selection, inference timeouts and the probe designation flag."
  def render(assigns) do
    assigns = assign(assigns, :form_control_classes, AdminComponents.form_control_classes())

    ~H"""
    <div class="flex flex-col">
      <h1 class="text-xl font-semibold">Registered LLM Models</h1>
      <AdminComponents.editing_toggle editing={@editing} />
      <nav class="flex flex-wrap items-center gap-3" aria-label="GenAI administration">
        <.link navigate={~p"/admin/gen_ai/providers"}>Providers and health</.link>
        <.link navigate={~p"/admin/gen_ai/service_configs"}>Service configurations</.link>
      </nav>
      <div class="my-3 flex flex-wrap items-center gap-3">
        <button
          type="button"
          phx-click="test"
          disabled={@testing or is_nil(@selected.id)}
          class="rounded border px-3 py-2"
        >
          Test Model
        </button>
        <p role="status" aria-live="polite">{@test_results}</p>
      </div>
      <div class="flex flex-col gap-4 lg:flex-row">
        <div class="flex w-full flex-col lg:w-1/2">
          <p :if={@registered_models == []}>
            No registered models yet. Configure a Provider, then create a model.
          </p>
          <ul aria-label="Registered models" role="list" class="divide-y divide-gray-100">
            <li :for={model <- @registered_models}>
              <button
                type="button"
                phx-click="select_model"
                phx-value-id={model.id}
                aria-pressed={to_string(@selected.id == model.id)}
                class={AdminComponents.list_item_classes(@selected.id == model.id)}
              >
                <div class="flex min-w-0 flex-col gap-x-4">
                  <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
                    {model.name}
                  </h3>
                  <div class="text-xs text-gray-800 dark:text-gray-100">
                    Model: <span class="font-mono">{model.model}</span>
                  </div>
                </div>
                <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
                  <p :if={model.health_check} class="mt-0 text-xs text-gray-500 dark:text-gray-400">
                    Health-check candidate
                  </p>
                  <p
                    :if={(model.service_config_count || 0) > 0}
                    class="mt-0 text-xs text-gray-500 dark:text-gray-400"
                  >
                    Used by <strong>{model.service_config_count}</strong> service config(s)
                  </p>
                  <p :if={(model.service_config_count || 0) == 0} class="mt-0 text-xs text-red-500">
                    No usages
                  </p>
                </div>
              </button>
            </li>
          </ul>
          <div class="mt-3">
            <button
              type="button"
              phx-click="new_model"
              disabled={!@editing}
              class="btn btn-primary btn-sm"
            >
              + New Model
            </button>
          </div>
        </div>
        <div class="w-full p-4 lg:w-1/2">
          <.form for={@form} id="registered-model-form" phx-submit="save">
            <.input
              field={@form[:name]}
              label="Friendly Name"
              class={@form_control_classes}
              disabled={!@editing}
            />
            <.input
              class={@form_control_classes}
              field={@form[:provider_id]}
              type="select"
              label="Configured Provider"
              prompt="Select a Provider"
              options={Enum.map(@providers, &{&1.name, &1.id})}
              disabled={!@editing}
            />
            <.input
              field={@form[:model]}
              label="Model"
              class={@form_control_classes}
              disabled={!@editing}
            />
            <.input
              class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700"
              field={@form[:health_check]}
              type="checkbox"
              label="Health-check candidate"
              disabled={!@editing}
            />
            <p class="text-sm">
              When several models are flagged, the lowest ID is selected. With no flag, the lowest-ID model is automatically designated.
            </p>
            <.input
              class={@form_control_classes}
              field={@form[:timeout]}
              type="number"
              min="1"
              label="Connection establishment timeout (ms)"
              disabled={!@editing}
            />
            <.input
              class={@form_control_classes}
              field={@form[:recv_timeout]}
              type="number"
              min="1"
              label="Response inactivity timeout (ms)"
              disabled={!@editing}
            />
            <p class="text-sm">
              Provider credentials are managed on the Providers page. Claude inference requires a managed transport implementation and is currently unsupported.
            </p>
            <div class="flex justify-between">
              <.button disabled={!@editing} class="mt-3 btn btn-primary" phx-disable-with="Saving…">
                Save
              </.button>
              <button
                type="button"
                phx-click="delete"
                disabled={
                  !@editing or is_nil(@selected.id) or (@selected.service_config_count || 0) > 0
                }
                data-confirm="Delete this unreferenced model?"
                class="mt-3 btn btn-danger"
              >
                Delete
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
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
