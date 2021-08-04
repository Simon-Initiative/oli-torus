defmodule OliWeb.Features.FeaturesLive do
  @moduledoc """
  LiveView implementation of a feature flag editor.
  """

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias Oli.Features

  def mount(_, _, socket) do
    {:ok,
     assign(socket,
       title: "Feature Flags",
       active: :features,
       features: Features.list_features_and_states(),
       breadcrumbs: [Breadcrumb.new(%{full_title: "Feature Flags"})]
     )}
  end

  defp current(:enabled), do: "Enabled"
  defp current(:disabled), do: "Disabled"

  defp action(:enabled), do: "Disable"
  defp action(:disabled), do: "Enable"

  defp to_state("Enable"), do: :enabled
  defp to_state("Disable"), do: :disabled

  def render(assigns) do
    ~L"""
    <div class="container">
      <div class="row">
        <div class="col-12">
          <p class="mb-3">
            Change the status of system-wide feature flags
          </p>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <table class="table table-striped table-bordered">
            <thead>
              <tr>
                <th>Feature</th>
                <th>Description</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <%= for {feature, status} <- @features do %>
                <tr>
                  <td><%= feature.label %></td>
                  <td><%= feature.description %></td>
                  <td><%= current(status) %></td>
                  <td>
                    <button type="button" class="btn btn-outline-danger" phx-click="toggle" phx-value-label="<%= feature.label %>" phx-value-action="<%= action(status) %>">
                      <%= action(status) %>
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

  def handle_event("toggle", %{"label" => label, "action" => action}, socket) do
    Features.change_state(label, to_state(action))
    {:noreply, assign(socket, features: Features.list_features_and_states())}
  end
end
