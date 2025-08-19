defmodule OliWeb.Sections.ProgressScoringLive do
  @moduledoc """
  LiveView for managing progress scoring configuration within course sections.

  Provides instructors with an interactive interface to:
  - Enable/disable progress scoring
  - Configure container selection (units/modules)
  - Set sync mode (automatic/manual)
  - Monitor sync status
  - Trigger manual syncs
  """

  use OliWeb, :live_view

  alias Oli.Delivery.Sections

  alias Oli.Delivery.Sections.{
    ProgressScoringManager,
    ProgressScoringMonitor
  }

  alias OliWeb.Common.{Breadcrumb, SessionContext}
  alias OliWeb.Sections.Mount
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.PubSub

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Progress Scoring",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, current_user, section} ->
        ctx = SessionContext.init(socket, session, current_user)

        # Subscribe to sync status updates
        sync_topic = "section:#{section.id}:progress_scoring:status"
        PubSub.subscribe(Oli.PubSub, sync_topic)

        {:ok, settings} = ProgressScoringManager.get_progress_scoring_settings(section.id)
        {sync_status, pending_count} = get_sync_status_safe(section.id)

        # Get available containers for the form
        containers =
          if settings.enabled and settings.hierarchy_type do
            case ProgressScoringManager.get_available_containers(
                   section.id,
                   settings.hierarchy_type
                 ) do
              {:ok, containers} -> containers
              {:error, _} -> []
            end
          else
            # Pre-load units as default containers for when user enables progress scoring
            case ProgressScoringManager.get_available_containers(section.id, :units) do
              {:ok, containers} -> containers
              {:error, _} -> []
            end
          end

        socket =
          socket
          |> assign(
            ctx: ctx,
            section: section,
            type: type,
            breadcrumbs: set_breadcrumbs(type, section),
            settings: settings,
            available_containers: containers,
            sync_status: sync_status,
            pending_sync_count: pending_count,
            show_validation_errors: false,
            loading: false
          )

        {:ok, socket}
    end
  end

  def handle_event("toggle_enabled", _params, socket) do
    enabled = !socket.assigns.settings.enabled

    section = socket.assigns.section

    socket = assign(socket, loading: true)

    if enabled do
      # When enabling, just show the form with default settings
      # Default to units hierarchy and load containers
      default_hierarchy = :units

      containers =
        case ProgressScoringManager.get_available_containers(section.id, default_hierarchy) do
          {:ok, containers} -> containers
          {:error, _} -> []
        end

      socket =
        socket
        |> assign(
          settings: %{socket.assigns.settings | enabled: true, hierarchy_type: default_hierarchy},
          available_containers: containers,
          loading: false,
          show_validation_errors: false
        )

      {:noreply, socket}
    else
      # When disabling, actually disable in the database
      case ProgressScoringManager.disable_progress_scoring(section.id) do
        {:ok, updated_settings} ->
          unmonitor_section_safe(section.id)

          socket =
            socket
            |> assign(
              settings: updated_settings,
              loading: false,
              show_validation_errors: false
            )

          {:noreply, socket}

        {:error, _reason} ->
          socket =
            socket
            |> assign(loading: false)
            |> put_flash(:error, "Failed to disable progress scoring")

          {:noreply, socket}
      end
    end
  end

  def handle_event("select_hierarchy", %{"hierarchy_type" => hierarchy_type}, socket) do
    hierarchy_atom = String.to_existing_atom(hierarchy_type)
    section = socket.assigns.section

    # Get containers for the selected hierarchy type
    case ProgressScoringManager.get_available_containers(section.id, hierarchy_atom) do
      {:ok, containers} ->
        updated_settings = %{
          socket.assigns.settings
          | hierarchy_type: hierarchy_atom,
            container_ids: []
        }

        socket =
          socket
          |> assign(
            settings: updated_settings,
            available_containers: containers
          )

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          put_flash(socket, :error, "Failed to load containers for selected hierarchy type")

        {:noreply, socket}
    end
  end

  def handle_event("toggle_container", %{"container_id" => container_id_str}, socket) do
    container_id = String.to_integer(container_id_str)
    current_ids = socket.assigns.settings.container_ids || []

    new_ids =
      if container_id in current_ids do
        List.delete(current_ids, container_id)
      else
        [container_id | current_ids]
      end

    updated_settings = %{socket.assigns.settings | container_ids: new_ids}

    socket = assign(socket, settings: updated_settings)
    {:noreply, socket}
  end

  def handle_event("change_sync_mode", %{"sync_mode" => sync_mode}, socket) do
    sync_mode_atom = String.to_existing_atom(sync_mode)
    updated_settings = %{socket.assigns.settings | sync_mode: sync_mode_atom}

    socket = assign(socket, settings: updated_settings)
    {:noreply, socket}
  end

  def handle_event("save_configuration", _params, socket) do
    section = socket.assigns.section
    settings = socket.assigns.settings

    socket = assign(socket, loading: true)

    case ProgressScoringManager.enable_progress_scoring(section.id, Map.from_struct(settings)) do
      {:ok, updated_settings} ->
        # Start monitoring this section
        monitor_section_safe(section.id)

        socket =
          socket
          |> assign(
            settings: updated_settings,
            loading: false,
            show_validation_errors: false
          )
          |> put_flash(:info, "Progress scoring configuration saved successfully")

        {:noreply, socket}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        socket =
          socket
          |> assign(loading: false, show_validation_errors: true)
          |> put_flash(:error, "Please fix the validation errors below")

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> assign(loading: false)
          |> put_flash(:error, "Failed to save configuration")

        {:noreply, socket}
    end
  end

  def handle_event("trigger_manual_sync", _params, socket) do
    section = socket.assigns.section

    # Get all enrolled students
    case Sections.enrolled_students(section) do
      students when is_list(students) ->
        user_ids = Enum.map(students, & &1.id)
        trigger_manual_sync_safe(section.id, user_ids)

        socket =
          put_flash(socket, :info, "Manual sync triggered for #{length(user_ids)} students")

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to get enrolled students")
        {:noreply, socket}
    end
  end

  def handle_event("refresh_status", _params, socket) do
    section = socket.assigns.section
    {sync_status, pending_count} = get_sync_status_safe(section.id)

    socket =
      socket
      |> assign(sync_status: sync_status, pending_sync_count: pending_count)

    {:noreply, socket}
  end

  # Handle PubSub messages for real-time updates
  def handle_info({:progress_sync_status, status, metadata}, socket) do
    {sync_status, pending_count} = get_sync_status_safe(socket.assigns.section.id)

    socket =
      socket
      |> assign(sync_status: sync_status, pending_sync_count: pending_count)
      |> maybe_show_sync_flash(status, metadata)

    {:noreply, socket}
  end

  defp maybe_show_sync_flash(socket, :manual_sync_triggered, %{user_count: count}) do
    put_flash(socket, :info, "Manual sync queued for #{count} students")
  end

  defp maybe_show_sync_flash(socket, :sync_queued, %{user_id: _user_id}) do
    # Don't flash for individual automatic syncs to avoid spam
    socket
  end

  defp maybe_show_sync_flash(socket, _status, _metadata) do
    socket
  end

  # Template rendering
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <div class="max-w-4xl mx-auto">
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h1 class="text-2xl font-bold text-gray-900">Progress Scoring Configuration</h1>
            <p class="mt-1 text-sm text-gray-600">
              Configure how student progress through course content contributes to their grade.
            </p>
          </div>

          <div class="px-6 py-6">
            <%= if @loading do %>
              <div class="flex items-center justify-center py-8">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                <span class="ml-2 text-gray-600">Processing...</span>
              </div>
            <% else %>
              <.progress_scoring_form
                settings={@settings}
                available_containers={@available_containers}
                sync_status={@sync_status}
                pending_sync_count={@pending_sync_count}
                show_validation_errors={@show_validation_errors}
              />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Form component
  attr :settings, :any, required: true
  attr :available_containers, :list, required: true
  attr :sync_status, :atom, required: true
  attr :pending_sync_count, :integer, required: true
  attr :show_validation_errors, :boolean, default: false

  def progress_scoring_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Enable/Disable Toggle -->
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-medium text-gray-900">Enable Progress Scoring</h3>
          <p class="text-sm text-gray-500">
            Allow student progress to contribute to their course grade
          </p>
        </div>
        <button
          type="button"
          phx-click="toggle_enabled"
          phx-value-enabled={not @settings.enabled}
          class={[
            "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
            if(@settings.enabled, do: "bg-blue-600", else: "bg-gray-200")
          ]}
        >
          <span class={[
            "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
            if(@settings.enabled, do: "translate-x-5", else: "translate-x-0")
          ]}>
          </span>
        </button>
      </div>

      <%= if @settings.enabled do %>
        <!-- Configuration Form -->
        <form phx-submit="save_configuration" class="space-y-6">
          <!-- Hierarchy Type Selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Content Hierarchy</label>
            <p class="text-sm text-gray-500">Select the level of content organization to track</p>
            <div class="mt-2 space-y-2">
              <label class="inline-flex items-center">
                <input
                  type="radio"
                  name="hierarchy_type"
                  value="units"
                  checked={@settings.hierarchy_type == :units}
                  phx-click="select_hierarchy"
                  phx-value-hierarchy_type="units"
                  class="form-radio"
                />
                <span class="ml-2">Units</span>
              </label>
              <label class="inline-flex items-center">
                <input
                  type="radio"
                  name="hierarchy_type"
                  value="modules"
                  checked={@settings.hierarchy_type == :modules}
                  phx-click="select_hierarchy"
                  phx-value-hierarchy_type="modules"
                  class="form-radio"
                />
                <span class="ml-2">Modules</span>
              </label>
            </div>
          </div>

          <%= if @settings.hierarchy_type && not Enum.empty?(@available_containers) do %>
            <!-- Container Selection -->
            <div>
              <label class="block text-sm font-medium text-gray-700">
                Select {String.capitalize(to_string(@settings.hierarchy_type))}
              </label>
              <p class="text-sm text-gray-500">
                Choose which content areas to include in progress calculation
              </p>
              <div class="mt-2 max-h-48 overflow-y-auto border border-gray-300 rounded-md p-2">
                <%= for container <- @available_containers do %>
                  <label class="flex items-center py-1">
                    <input
                      type="checkbox"
                      checked={container.id in (@settings.container_ids || [])}
                      phx-click="toggle_container"
                      phx-value-container_id={container.id}
                      class="form-checkbox"
                    />
                    <span class="ml-2 text-sm">{container.title}</span>
                  </label>
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Sync Mode Selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700">Sync Mode</label>
            <p class="text-sm text-gray-500">How grades should be updated in the LMS</p>
            <div class="mt-2 space-y-2">
              <label class="inline-flex items-center">
                <input
                  type="radio"
                  name="sync_mode"
                  value="automatic"
                  checked={@settings.sync_mode == :automatic}
                  phx-click="change_sync_mode"
                  phx-value-sync_mode="automatic"
                  class="form-radio"
                />
                <span class="ml-2">Automatic - sync immediately when progress changes</span>
              </label>
              <label class="inline-flex items-center">
                <input
                  type="radio"
                  name="sync_mode"
                  value="manual"
                  checked={@settings.sync_mode == :manual}
                  phx-click="change_sync_mode"
                  phx-value-sync_mode="manual"
                  class="form-radio"
                />
                <span class="ml-2">Manual - sync only when triggered by instructor</span>
              </label>
            </div>
          </div>
          
    <!-- Save Button -->
          <div class="flex justify-end">
            <button
              type="submit"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Save Configuration
            </button>
          </div>
        </form>
      <% end %>
      
    <!-- Sync Status -->
      <div class="border-t pt-6">
        <h3 class="text-lg font-medium text-gray-900">Sync Status</h3>
        <div class="mt-2 flex items-center justify-between">
          <div>
            <p class="text-sm text-gray-600">
              Status: <span class="font-medium">{format_sync_status(@sync_status)}</span>
            </p>
            <%= if @pending_sync_count > 0 do %>
              <p class="text-sm text-gray-600">
                Pending syncs: <span class="font-medium">{@pending_sync_count}</span>
              </p>
            <% end %>
          </div>
          <div class="space-x-2">
            <button
              type="button"
              phx-click="refresh_status"
              class="inline-flex items-center px-3 py-1 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50"
            >
              Refresh
            </button>
            <%= if @settings.sync_mode == :manual do %>
              <button
                type="button"
                phx-click="trigger_manual_sync"
                class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded text-white bg-blue-600 hover:bg-blue-700"
              >
                Sync Now
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_sync_status(:not_monitored), do: "Not monitored"
  defp format_sync_status(:disabled), do: "Disabled"
  defp format_sync_status(:manual_mode), do: "Manual mode"
  defp format_sync_status(:automatic_mode), do: "Automatic mode"
  defp format_sync_status(:monitor_not_running), do: "Monitor not running"
  defp format_sync_status(:monitor_timeout), do: "Monitor timeout"
  defp format_sync_status(_), do: "Unknown"

  # Helper functions to safely call monitor even when it's not running
  defp get_sync_status_safe(section_id) do
    try do
      ProgressScoringMonitor.get_sync_status(section_id)
    catch
      :exit, {:noproc, _} ->
        # Monitor is not running, return default status
        {:monitor_not_running, 0}

      :exit, {:timeout, _} ->
        # Monitor is running but not responding, return default status
        {:monitor_timeout, 0}
    end
  end

  defp monitor_section_safe(section_id) do
    try do
      ProgressScoringMonitor.monitor_section(section_id)
    catch
      :exit, {:noproc, _} ->
        :monitor_not_running

      :exit, {:timeout, _} ->
        :monitor_timeout
    end
  end

  defp unmonitor_section_safe(section_id) do
    try do
      ProgressScoringMonitor.unmonitor_section(section_id)
    catch
      :exit, {:noproc, _} ->
        :monitor_not_running

      :exit, {:timeout, _} ->
        :monitor_timeout
    end
  end

  defp trigger_manual_sync_safe(section_id, user_ids) do
    try do
      ProgressScoringMonitor.trigger_manual_sync(section_id, user_ids)
    catch
      :exit, {:noproc, _} ->
        :monitor_not_running

      :exit, {:timeout, _} ->
        :monitor_timeout
    end
  end
end
