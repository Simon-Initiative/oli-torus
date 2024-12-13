defmodule OliWeb.ApiKeys.ApiKeysLive do
  @moduledoc """
  LiveView implementation of a API Keys management.
  """

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage API Keys",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  defp all_keys_sorted do
    Oli.Interop.list_api_keys()
    |> Enum.sort_by(& &1.hint, :asc)
  end

  def mount(_, _, socket) do
    {:ok,
     assign(socket,
       title: "API Keys",
       active: :keys,
       hint: "",
       created_key: "",
       keys: all_keys_sorted(),
       breadcrumbs: set_breadcrumbs()
     )}
  end

  defp current(:enabled), do: "Enabled"
  defp current(:disabled), do: "Disabled"

  defp action(:enabled), do: "Disable"
  defp action(:disabled), do: "Enable"

  defp to_state("Enable"), do: :enabled
  defp to_state("Disable"), do: :disabled

  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <p class="mb-3">
            Enter a description/hint for a new API key:
          </p>
          <input type="text" phx-change="hint" phx-keyup="hint" phx-blur="hint" />

          <button type="button" class="btn btn-primary" phx-click="create" disabled={@hint == ""}>
            Create New
          </button>

          <%= if @created_key != "" do %>
            <p>This is the API key.  Copy this now, this is the only time you will see this.</p>
            <p><strong><code><%= @created_key %></code></strong></p>
          <% end %>
        </div>
      </div>
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <p class="mb-3 mt-5">
            Change the status of existing API
          </p>
        </div>
      </div>
      <div class="grid grid-cols-12">
        <div class="col-span-12">
          <table class="table table-striped table-bordered">
            <thead>
              <tr>
                <th>Key Hint</th>
                <th>Status</th>
                <th>Payments Enabled</th>
                <th>Prodcuts Enabled</th>
                <th>Registration Enabled</th>
                <th>Registration Namespace</th>
                <th>Automation Data<br />Setup Enabled</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <%= for key <- @keys do %>
                <tr>
                  <td><%= key.hint %></td>
                  <td><%= current(key.status) %></td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="update"
                      phx-value-field="payments_enabled"
                      phx-value-id={key.id}
                      phx-value-action={
                        if key.payments_enabled do
                          "false"
                        else
                          "true"
                        end
                      }
                    >
                      <%= key.payments_enabled %>
                    </button>
                  </td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="update"
                      phx-value-field="products_enabled"
                      phx-value-id={key.id}
                      phx-value-action={
                        if key.products_enabled do
                          "false"
                        else
                          "true"
                        end
                      }
                    >
                      <%= key.products_enabled %>
                    </button>
                  </td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="update"
                      phx-value-field="registration_enabled"
                      phx-value-id={key.id}
                      phx-value-action={
                        if key.registration_enabled do
                          "false"
                        else
                          "true"
                        end
                      }
                    >
                      <%= key.registration_enabled %>
                    </button>
                  </td>
                  <td>
                    <input
                      id={"text_#{key.id}"}
                      type="text"
                      phx-hook="TextInputListener"
                      value={key.registration_namespace}
                    />
                  </td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="update"
                      phx-value-field="automation_setup_enabled"
                      phx-value-id={key.id}
                      phx-value-action={
                        if key.automation_setup_enabled do
                          "false"
                        else
                          "true"
                        end
                      }
                    >
                      <%= key.automation_setup_enabled %>
                    </button>
                  </td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="toggle"
                      phx-value-id={key.id}
                      phx-value-action={action(key.status)}
                    >
                      <%= action(key.status) %>
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("hint", %{"value" => hint}, socket) do
    {:noreply, assign(socket, hint: hint)}
  end

  def handle_event("create", _, socket) do
    created_key = UUID.uuid4()

    case Oli.Interop.create_key(created_key, socket.assigns.hint) do
      {:ok, _} ->
        {:noreply, assign(socket, created_key: created_key, keys: all_keys_sorted())}

      {:error, _} ->
        socket
        |> put_flash(:error, "Could not create API key")
    end
  end

  def handle_event("change", %{"id" => "text_" <> id, "value" => namespace}, socket) do
    Oli.Interop.get_key(id)
    |> Oli.Interop.update_key(%{registration_namespace: namespace})

    {:noreply, assign(socket, keys: all_keys_sorted())}
  end

  def handle_event("toggle", %{"id" => id, "action" => action}, socket) do
    Oli.Interop.get_key(id)
    |> Oli.Interop.update_key(%{status: to_state(action)})

    {:noreply, assign(socket, keys: all_keys_sorted())}
  end

  def handle_event("update", %{"field" => field, "id" => id, "action" => action}, socket) do
    attrs =
      Map.put(
        %{},
        String.to_existing_atom(field),
        if action == "true" do
          true
        else
          false
        end
      )

    Oli.Interop.get_key(id)
    |> Oli.Interop.update_key(attrs)

    {:noreply, assign(socket, keys: all_keys_sorted())}
  end
end
