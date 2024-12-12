defmodule OliWeb.Features.FeaturesLive do
  @moduledoc """
  LiveView implementation of a feature flag editor.
  """

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias Oli.Features
  alias Oli.Delivery

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{full_title: "Feature Flags"})
      ]
  end

  def mount(_, _, socket) do
    research_consent_form_setting = Delivery.get_research_consent_form_setting()

    {:ok,
     assign(socket,
       title: "Feature Flags",
       log_level: Logger.level(),
       active: :features,
       features: Features.list_features_and_states(),
       breadcrumbs: set_breadcrumbs(),
       research_consent_form_setting: research_consent_form_setting
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
      <div class="grid grid-cols-12 mb-5">
        <div class="col-span-12">
          <h2 class="mb-5">
            Change the logging level of the system.
          </h2>
          <p class="mb-5">
            Current log level is: <strong><mark><%= @log_level %></mark></strong>.
          </p>
          <p>
            <button type="button" class="btn btn-danger" phx-click="logging" phx-value-level="debug">
              Debug (most verbose)
            </button>
            <button type="button" class="btn btn-secondary" phx-click="logging" phx-value-level="info">
              Info
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="notice"
            >
              Notice
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="warning"
            >
              Warning
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="error"
            >
              Error
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="critical"
            >
              Critical
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="alert"
            >
              Alert
            </button>
            <button
              type="button"
              class="btn btn-secondary"
              phx-click="logging"
              phx-value-level="emergency"
            >
              Emergency (least verbose)
            </button>
          </p>
        </div>
      </div>
      <div class="grid grid-cols-12 mt-5">
        <div class="col-span-12">
          <h2 class="mb-5">
            Change the status of system-wide feature flags
          </h2>
        </div>
      </div>
      <div class="grid grid-cols-12">
        <div class="col-span-12">
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
                    <button
                      type="button"
                      class="btn btn-outline-danger"
                      phx-click="toggle"
                      phx-value-label={feature.label}
                      phx-value-action={action(status)}
                    >
                      <%= action(status) %>
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-5">
        <h2 class="mb-5">
          Research Consent
        </h2>
      </div>
      <div class="flex flex-row">
        <.form :let={f} for={%{}} phx-change="change_research_consent_form">
          <label for="countries" class="block mb-2 text-sm font-medium text-gray-900 dark:text-white">
            Direct Delivery Research Consent Form
          </label>

          <.input
            field={f[:research_consent_form]}
            type="select"
            value={@research_consent_form_setting}
            options={[{"OLI Form", :oli_form}, {"No Form", :no_form}]}
            class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
          >
          </.input>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("toggle", %{"label" => label, "action" => action}, socket) do
    Features.change_state(label, to_state(action))
    {:noreply, assign(socket, features: Features.list_features_and_states())}
  end

  def handle_event("logging", %{"level" => level}, socket) do
    socket =
      case Logger.configure(level: String.to_atom(level)) do
        :ok ->
          socket
          |> put_flash(:info, "Logging level changed to #{level}")
          |> assign(log_level: Logger.level())

        _ ->
          socket
          |> put_flash(:error, "Logging level could not be changed to #{level}")
      end

    {:noreply, socket}
  end

  def handle_event(
        "change_research_consent_form",
        %{"research_consent_form" => research_consent_form},
        socket
      ) do
    research_consent_form_selection = String.to_existing_atom(research_consent_form)

    Delivery.update_research_consent_form_setting(research_consent_form_selection)

    {:noreply, assign(socket, research_consent_form_setting: research_consent_form_selection)}
  end
end
