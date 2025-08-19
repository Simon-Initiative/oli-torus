defmodule Oli.Delivery.Sections.ProgressScoringMonitor do
  @moduledoc """
  GenServer for monitoring progress updates and coordinating automatic sync operations.

  This monitor:
  - Subscribes to progress update events via PubSub
  - Manages the lifecycle of progress scoring sync operations
  - Coordinates automatic vs manual sync modes
  - Provides real-time status updates for the UI

  The monitor is designed to be resilient and efficient:
  - Graceful restart handling with state recovery
  - Debouncing to prevent excessive sync job creation
  - Memory-efficient tracking of active sections
  """

  use GenServer

  require Logger

  alias Phoenix.PubSub

  alias Oli.Delivery.Sections.{
    ProgressScoringManager,
    ProgressSyncWorker
  }

  @pubsub Oli.PubSub
  @progress_update_topic "resource_access_progress_update"
  # 5 seconds debounce
  @debounce_interval 5_000

  defmodule State do
    @moduledoc false
    defstruct [
      # Map of section_id => %{enabled: boolean, sync_mode: atom, last_update: timestamp}
      monitored_sections: %{},
      # Map of section_id => user_id => timer_ref for debouncing
      pending_syncs: %{}
    ]
  end

  ## Client API

  @doc """
  Starts the progress scoring monitor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a section for progress scoring monitoring.
  """
  def monitor_section(section_id) do
    GenServer.cast(__MODULE__, {:monitor_section, section_id})
  end

  @doc """
  Unregisters a section from progress scoring monitoring.
  """
  def unmonitor_section(section_id) do
    GenServer.cast(__MODULE__, {:unmonitor_section, section_id})
  end

  @doc """
  Gets the current sync status for a section.
  """
  def get_sync_status(section_id) do
    GenServer.call(__MODULE__, {:get_sync_status, section_id})
  end

  @doc """
  Triggers a manual sync for specific users in a section.
  """
  def trigger_manual_sync(section_id, user_ids) do
    GenServer.cast(__MODULE__, {:trigger_manual_sync, section_id, user_ids})
  end

  @doc """
  Refreshes the monitoring configuration for a section.
  """
  def refresh_section_config(section_id) do
    GenServer.cast(__MODULE__, {:refresh_section_config, section_id})
  end

  ## Server Implementation

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting ProgressScoringMonitor")

    # Subscribe to progress update events
    PubSub.subscribe(@pubsub, @progress_update_topic)

    # Initialize monitoring for all sections with progress scoring enabled
    spawn_link(fn -> initialize_monitoring() end)

    {:ok, %State{}}
  end

  @impl GenServer
  def handle_cast({:monitor_section, section_id}, state) do
    case load_section_config(section_id) do
      {:ok, config} ->
        Logger.debug("Monitoring section for progress scoring", section_id: section_id)

        new_sections = Map.put(state.monitored_sections, section_id, config)
        {:noreply, %{state | monitored_sections: new_sections}}

      {:error, reason} ->
        Logger.warning("Failed to load section config for monitoring",
          section_id: section_id,
          reason: inspect(reason)
        )

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:unmonitor_section, section_id}, state) do
    Logger.debug("Unmonitoring section for progress scoring", section_id: section_id)

    # Cancel any pending syncs for this section
    new_pending = cancel_pending_syncs_for_section(state.pending_syncs, section_id)
    new_sections = Map.delete(state.monitored_sections, section_id)

    {:noreply, %{state | monitored_sections: new_sections, pending_syncs: new_pending}}
  end

  @impl GenServer
  def handle_cast({:trigger_manual_sync, section_id, user_ids}, state) do
    case Map.get(state.monitored_sections, section_id) do
      nil ->
        Logger.warning("Attempted manual sync for unmonitored section", section_id: section_id)
        {:noreply, state}

      _config ->
        Logger.info("Triggering manual sync",
          section_id: section_id,
          user_count: length(user_ids)
        )

        # Create sync jobs with high priority for manual syncs
        case ProgressSyncWorker.create_manual(section_id, user_ids) do
          {:ok, _jobs} ->
            broadcast_sync_status(section_id, :manual_sync_triggered, %{
              user_count: length(user_ids)
            })

          {:error, reason} ->
            Logger.error("Failed to create manual sync jobs",
              section_id: section_id,
              reason: inspect(reason)
            )
        end

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:refresh_section_config, section_id}, state) do
    case load_section_config(section_id) do
      {:ok, config} ->
        new_sections = Map.put(state.monitored_sections, section_id, config)
        {:noreply, %{state | monitored_sections: new_sections}}

      {:error, _reason} ->
        # Remove from monitoring if config can't be loaded
        new_sections = Map.delete(state.monitored_sections, section_id)
        new_pending = cancel_pending_syncs_for_section(state.pending_syncs, section_id)
        {:noreply, %{state | monitored_sections: new_sections, pending_syncs: new_pending}}
    end
  end

  @impl GenServer
  def handle_call({:get_sync_status, section_id}, _from, state) do
    status =
      case Map.get(state.monitored_sections, section_id) do
        nil -> :not_monitored
        %{enabled: false} -> :disabled
        %{sync_mode: :manual} -> :manual_mode
        %{sync_mode: :automatic} -> :automatic_mode
      end

    pending_count =
      state.pending_syncs
      |> Map.get(section_id, %{})
      |> map_size()

    {:reply, {status, pending_count}, state}
  end

  @impl GenServer
  def handle_info({:progress_update, %{section_id: section_id, user_id: user_id}}, state) do
    case Map.get(state.monitored_sections, section_id) do
      %{enabled: true, sync_mode: :automatic} ->
        new_pending = schedule_debounced_sync(state.pending_syncs, section_id, user_id)
        {:noreply, %{state | pending_syncs: new_pending}}

      _ ->
        # Not monitoring this section or not in automatic mode
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:execute_sync, section_id, user_id}, state) do
    # Remove from pending syncs
    new_pending = remove_pending_sync(state.pending_syncs, section_id, user_id)

    # Create sync job
    case ProgressSyncWorker.create(section_id, user_id) do
      {:ok, _job} ->
        Logger.debug("Created automatic sync job", section_id: section_id, user_id: user_id)
        broadcast_sync_status(section_id, :sync_queued, %{user_id: user_id})

      {:error, reason} ->
        Logger.error("Failed to create automatic sync job",
          section_id: section_id,
          user_id: user_id,
          reason: inspect(reason)
        )
    end

    {:noreply, %{state | pending_syncs: new_pending}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private helper functions

  defp initialize_monitoring do
    # Find all sections with progress scoring enabled
    case ProgressScoringManager.get_enabled_sections() do
      {:ok, section_ids} ->
        Enum.each(section_ids, &monitor_section/1)

      {:error, reason} ->
        Logger.error("Failed to initialize progress scoring monitoring", reason: inspect(reason))
    end
  end

  defp load_section_config(section_id) do
    case ProgressScoringManager.get_progress_scoring_settings(section_id) do
      {:ok, %{enabled: true} = settings} ->
        config = %{
          enabled: true,
          sync_mode: settings.sync_mode,
          last_update: DateTime.utc_now()
        }

        {:ok, config}

      {:ok, %{enabled: false}} ->
        {:error, :progress_scoring_disabled}

      error ->
        error
    end
  end

  defp schedule_debounced_sync(pending_syncs, section_id, user_id) do
    # Cancel existing timer if present
    section_pending = Map.get(pending_syncs, section_id, %{})

    case Map.get(section_pending, user_id) do
      nil -> :ok
      timer_ref -> Process.cancel_timer(timer_ref)
    end

    # Schedule new timer
    timer_ref =
      Process.send_after(self(), {:execute_sync, section_id, user_id}, @debounce_interval)

    new_section_pending = Map.put(section_pending, user_id, timer_ref)
    Map.put(pending_syncs, section_id, new_section_pending)
  end

  defp remove_pending_sync(pending_syncs, section_id, user_id) do
    section_pending = Map.get(pending_syncs, section_id, %{})
    new_section_pending = Map.delete(section_pending, user_id)

    if map_size(new_section_pending) == 0 do
      Map.delete(pending_syncs, section_id)
    else
      Map.put(pending_syncs, section_id, new_section_pending)
    end
  end

  defp cancel_pending_syncs_for_section(pending_syncs, section_id) do
    case Map.get(pending_syncs, section_id) do
      nil ->
        pending_syncs

      section_pending ->
        # Cancel all timers for this section
        Enum.each(section_pending, fn {_user_id, timer_ref} ->
          Process.cancel_timer(timer_ref)
        end)

        Map.delete(pending_syncs, section_id)
    end
  end

  defp broadcast_sync_status(section_id, status, metadata) do
    topic = "section:#{section_id}:progress_scoring:status"
    message = {:progress_sync_status, status, metadata}

    PubSub.broadcast(@pubsub, topic, message)
  end
end
