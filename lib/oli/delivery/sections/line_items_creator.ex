defmodule Oli.Delivery.Sections.LineItemsCreator do
  @moduledoc """
  GenServer for asynchronously creating LMS line items for assessments and progress containers.

  This server handles bulk creation of line items in course order, allowing the user
  to close the LiveView while the operation continues in the background.
  """

  use GenServer
  require Logger

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.ProgressGradeLineItem
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.AGS.LineItem
  alias Oli.Lti.AccessTokenLibrary
  alias Oli.Grading
  alias Phoenix.PubSub

  # Client API

  @doc """
  Starts the GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Initiates the creation of all line items for a section.

  Returns {:ok, job_id} or {:error, reason}
  """
  def create_all_line_items(section_slug, opts \\ []) do
    job_id = generate_job_id()

    # Start a new GenServer for this job
    case DynamicSupervisor.start_child(
           Oli.DynamicSupervisor,
           {__MODULE__, name: via_tuple(job_id)}
         ) do
      {:ok, _pid} ->
        # Send the work to the GenServer
        GenServer.cast(via_tuple(job_id), {:create_line_items, section_slug, job_id, opts})
        {:ok, job_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the status of a line items creation job.
  """
  def get_status(job_id) do
    case GenServer.whereis(via_tuple(job_id)) do
      nil -> {:error, :job_not_found}
      pid -> GenServer.call(pid, :get_status)
    end
  end

  @doc """
  Cancels a line items creation job.
  """
  def cancel(job_id) do
    case GenServer.whereis(via_tuple(job_id)) do
      nil -> {:error, :job_not_found}
      pid -> GenServer.call(pid, :cancel)
    end
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    {:ok,
     %{
       status: :idle,
       job_id: nil,
       section_slug: nil,
       total_items: 0,
       processed_items: 0,
       failed_items: 0,
       errors: [],
       cancelled: false,
       started_at: nil,
       completed_at: nil
     }}
  end

  @impl true
  def handle_cast({:create_line_items, section_slug, job_id, opts}, state) do
    state = %{
      state
      | status: :running,
        job_id: job_id,
        section_slug: section_slug,
        started_at: DateTime.utc_now()
    }

    # Broadcast that the job has started
    broadcast_status(state)

    # Start processing in a separate task
    Task.start(fn -> process_line_items(self(), section_slug, opts) end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, format_status_map(state), state}
  end

  @impl true
  def handle_call(:cancel, _from, state) do
    state = %{state | cancelled: true, status: :cancelled}
    broadcast_status(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:update_progress, updates}, state) do
    state = Map.merge(state, updates)
    broadcast_status(state)

    # If the job is complete, stop the GenServer after a delay
    if state.status in [:completed, :failed, :cancelled] do
      # Keep alive for 1 minute for status queries
      Process.send_after(self(), :shutdown, 60_000)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  # Private Functions

  defp via_tuple(job_id) do
    {:via, Registry, {Oli.Delivery.LineItemsRegistry, job_id}}
  end

  defp generate_job_id do
    "line_items_#{System.unique_integer([:positive])}_#{System.system_time(:millisecond)}"
  end

  @impl true
  def format_status(:normal, [_pdict, state]) do
    [{:data, [{~c"State", format_status_map(state)}]}]
  end

  @impl true
  def format_status(:terminate, state) do
    format_status_map(state)
  end

  defp format_status_map(state) do
    %{
      job_id: state.job_id,
      status: state.status,
      progress: %{
        total: state.total_items,
        processed: state.processed_items,
        failed: state.failed_items
      },
      errors: state.errors,
      started_at: state.started_at,
      completed_at: state.completed_at
    }
  end

  defp broadcast_status(state) do
    PubSub.broadcast(
      Oli.PubSub,
      "line_items_creator:#{state.section_slug}",
      {:line_items_status, format_status_map(state)}
    )
  end

  defp process_line_items(server_pid, section_slug, _opts) do
    try do
      section = Sections.get_section_by_slug(section_slug)
      {_deployment, registration} = Sections.get_deployment_registration_from_section(section)

      # Get access token
      case fetch_access_token(registration) do
        {:ok, access_token} ->
          # Get existing line items
          case AGS.fetch_line_items(section.line_items_service_url, access_token) do
            {:ok, existing_line_items} ->
              # Build ordered list of all items to create/update
              items_to_process = build_ordered_items_list(section, existing_line_items)

              # Update total count
              send(server_pid, {:update_progress, %{total_items: length(items_to_process)}})

              # Process each item
              process_items(
                server_pid,
                items_to_process,
                section,
                access_token,
                existing_line_items
              )

            {:error, reason} ->
              send(
                server_pid,
                {:update_progress,
                 %{
                   status: :failed,
                   errors: ["Failed to fetch existing line items: #{inspect(reason)}"],
                   completed_at: DateTime.utc_now()
                 }}
              )
          end

        {:error, reason} ->
          send(
            server_pid,
            {:update_progress,
             %{
               status: :failed,
               errors: ["Failed to get access token: #{inspect(reason)}"],
               completed_at: DateTime.utc_now()
             }}
          )
      end
    rescue
      e ->
        Logger.error("Error in line items creator: #{inspect(e)}")

        send(
          server_pid,
          {:update_progress,
           %{
             status: :failed,
             errors: ["Unexpected error: #{inspect(e)}"],
             completed_at: DateTime.utc_now()
           }}
        )
    end
  end

  defp fetch_access_token(registration) do
    provider =
      :oli
      |> Application.get_env(:lti_access_token_provider)
      |> Keyword.get(:provider, AccessTokenLibrary)

    host =
      Application.get_env(:oli, OliWeb.Endpoint)
      |> Keyword.get(:url)
      |> Keyword.get(:host)

    provider.fetch_access_token(registration, Grading.ags_scopes(), host)
  end

  defp build_ordered_items_list(section, _existing_line_items) do
    # Use the efficient function from Oli.Grading that uses SectionResourceDepot
    Grading.determine_all_scored_items(section)
  end

  defp process_items(server_pid, items, section, access_token, existing_line_items) do
    line_item_map =
      Enum.reduce(existing_line_items, %{}, fn i, m ->
        Map.put(m, i.resourceId, i)
      end)

    Enum.reduce(items, %{processed: 0, failed: 0, errors: []}, fn item, acc ->
      # Check if cancelled
      case GenServer.whereis(server_pid) do
        # Server stopped
        nil ->
          acc

        _pid ->
          status = GenServer.call(server_pid, :get_status)

          if status.status == :cancelled do
            # Stop processing
            acc
          else
            # Process this item
            result = process_single_item(item, section, access_token, line_item_map)

            {processed, failed, errors} =
              case result do
                {:ok, _} ->
                  {acc.processed + 1, acc.failed, acc.errors}

                {:error, reason} ->
                  error_msg = "Failed to process #{item.type} '#{item.title}': #{inspect(reason)}"
                  Logger.error(error_msg)
                  {acc.processed, acc.failed + 1, [error_msg | acc.errors]}
              end

            # Update progress
            send(
              server_pid,
              {:update_progress,
               %{
                 processed_items: processed,
                 failed_items: failed,
                 errors: errors
               }}
            )

            %{processed: processed, failed: failed, errors: errors}
          end
      end
    end)

    # Mark as completed
    send(
      server_pid,
      {:update_progress,
       %{
         status: :completed,
         completed_at: DateTime.utc_now()
       }}
    )
  end

  defp process_single_item(
         %{type: :progress_container} = item,
         section,
         access_token,
         line_item_map
       ) do
    resource_id = ProgressGradeLineItem.progress_score_resource_id(item.container_id)

    # Check if needs creation or update
    if Map.has_key?(line_item_map, resource_id) do
      # Check if label needs update
      line_item = Map.get(line_item_map, resource_id)

      expected_label =
        ProgressGradeLineItem.progress_score_label(
          section.title,
          item.title,
          item.hierarchy_type
        )

      if line_item.label != expected_label do
        AGS.update_line_item(line_item, %{label: expected_label}, access_token)
      else
        {:ok, :unchanged}
      end
    else
      # Create new line item
      label =
        ProgressGradeLineItem.progress_score_label(
          section.title,
          item.title,
          item.hierarchy_type
        )

      AGS.create_line_item(
        section.line_items_service_url,
        resource_id,
        item.out_of,
        label,
        access_token
      )
    end
  end

  defp process_single_item(%{type: :assessment} = item, section, access_token, line_item_map) do
    resource_id = LineItem.to_resource_id(item.resource_id)

    # Check if needs creation or update
    if Map.has_key?(line_item_map, resource_id) do
      # Check if label needs update
      line_item = Map.get(line_item_map, resource_id)

      if line_item.label != item.title do
        AGS.update_line_item(line_item, %{label: item.title}, access_token)
      else
        {:ok, :unchanged}
      end
    else
      # Create new line item
      AGS.create_line_item(
        section.line_items_service_url,
        item.resource_id,
        item.out_of,
        item.title,
        access_token
      )
    end
  end
end
