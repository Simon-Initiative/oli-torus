defmodule Oli.Analytics.XAPI.QueueProducer do
  @moduledoc """
  This module is a Broadway producer that manages a queue of statement
  bundles to be uploaded to S3. Clients of this code enqueue statement
  bundles to be uploaded by calling `Oli.Analytics.XAPI.QueueProducer.enqueue/1`.
  """

  use GenStage
  require Logger
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Analytics.XAPI.PendingUpload

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    pending_items = enqueue_from_storage()

    initial_state = %{
      demand: 0,
      queue: pending_items,
      queue_size: Enum.count(pending_items)
    }

    {:producer, initial_state}
  end

  # This is the public API for enqueuing a statement bundle
  # to be uploaded to S3.  Everything else in this module faces
  # the Broadway pipeline.
  def enqueue(%StatementBundle{} = bundle) do
    # This seems to be the most future proof way, randomly selecting 1 on n producers
    # to send the message to.  This is a good way to ensure that the load is distributed
    # should we ever need to add additional queues.
    producer_name = Broadway.producer_names(Oli.Analytics.XAPI.UploadPipeline) |> Enum.random()

    # Async call to the producer
    GenStage.cast(producer_name, {:insert, bundle})
  end

  def handle_cast({:insert, bundle}, state) do
    state = %{state | queue: [bundle | state.queue]}
    handle_receive_messages(state)
  end

  def handle_demand(incoming_demand, %{demand: demand} = state) do
    handle_receive_messages(%{state | demand: demand + incoming_demand})
  end

  def prepare_for_draining(%{} = state) do
    Logger.info("Draining XAPI queue with #{Enum.count(state.queue)} messages")
    persist(state.queue)

    {:noreply, [], %{state | queue: []}}
  end

  defp handle_receive_messages(%{demand: demand, queue: queue} = state) when demand > 0 do
    {remaining, to_send} = Enum.split(queue, -demand)
    satisfied_count = Enum.count(to_send)
    demand = demand - satisfied_count

    Utils.record_pipeline_stats(%{queue_size: Enum.count(remaining), demand: demand})
    Logger.debug("Satisfying demand of #{demand} with #{satisfied_count}")

    {:noreply, to_send,
     %{state | demand: demand, queue: remaining, queue_size: Enum.count(remaining)}}
  end

  defp handle_receive_messages(state) do
    Utils.record_pipeline_stats(%{queue_size: Enum.count(state.queue), demand: 0})
    {:noreply, [], state}
  end

  # Persist a list of statement bundles to the database
  def persist(bundles, reason \\ :drained) when is_list(bundles) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    inserts =
      Enum.map(bundles, fn b ->
        %{
          reason: reason,
          bundle: b,
          inserted_at: now,
          updated_at: now
        }
      end)

    expected_count = Enum.count(bundles)
    {count, _} = Oli.Repo.insert_all(PendingUpload, inserts)

    case count do
      ^expected_count -> {:ok, count}
      _ -> {:error, count}
    end
  end

  def enqueue_from_storage() do
    {:ok, all} =
      Oli.Repo.transaction(fn ->
        all =
          Oli.Repo.all(PendingUpload)
          |> Enum.map(fn pu ->
            %StatementBundle{
              partition: pu.bundle["partition"],
              partition_id: pu.bundle["partition_id"],
              category: pu.bundle["category"],
              bundle_id: pu.bundle["bundle_id"],
              body: pu.bundle["body"]
            }
          end)

        Oli.Repo.delete_all(PendingUpload)

        all
      end)

    all
  end
end
