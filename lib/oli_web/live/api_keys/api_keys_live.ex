defmodule OliWeb.ApiKeys.ApiKeysLive do
  @moduledoc """
  LiveView implementation of a API Keys management.
  """

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb

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
       breadcrumbs: [Breadcrumb.new(%{full_title: "API Keys"})]
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
      <div class="row">
        <div class="col-12">
          <p class="mb-3">
            Enter a description/hint for a new API key:
          </p>
          <input type="text" phx-change="hint" phx-keyup="hint" phx-blur="hint"/>

          <button type="button" class="btn btn-primary" phx-click="create" disabled={@hint == ""}>
            Create New
          </button>

          <%= if @created_key != "" do %>
          <p>This is the API key.  Copy this now, this is the only time you will see this.</p>
          <p><strong><code><%= @created_key %></code></strong></p>
          <% end %>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <p class="mb-3 mt-5">
            Change the status of existing API
          </p>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <table class="table table-striped table-bordered">
            <thead>
              <tr>
                <th>Key Hint</th>
                <th>Status</th>
                <th>Payments Enabled</th>
                <th>Prodcuts Enabled</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <%= for key <- @keys do %>
                <tr>
                  <td><%= key.hint %></td>
                  <td><%= current(key.status) %></td>
                  <td><%= key.payments_enabled %></td>
                  <td><%= key.products_enabled %></td>
                  <td>
                    <button type="button" class="btn btn-outline-danger" phx-click="toggle" phx-value-id={key.id} phx-value-action={action(key.status)}>
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
        |> put_flash(:error, "Could not edit objective")
    end
  end

  def handle_event("toggle", %{"id" => id, "action" => action}, socket) do
    Oli.Interop.get_key(id)
    |> Oli.Interop.update_key(%{status: to_state(action)})

    {:noreply, assign(socket, keys: all_keys_sorted())}
  end
end
