defmodule Oli.Publishing.PartMappingRefreshWorker do
  @moduledoc """
    An Oban worker for refreshing the part_mapping materialized view.
    The view must be refreshed at least once after a Publication update is made.
    Since the complete view is refreshed, we avoid duplicate jobs in the queue, and only queue one max job if there's one being executed.

    In Oli.Application the part_mapping_refresh queue is setup to be only configured in one node of the cluster. This is to ensure that only one node
    is trying to refresh the view at any time.
  """

  use Oban.Worker,
    queue: :part_mapping_refresh,
    # We're stating that all jobs scheduled or available are the same.
    # if a there's a job in the queue (unless it's already executing), we don't want to queue another one.
    unique: [fields: [:queue, :worker], states: [:scheduled, :available]]

  import Ecto.Query, warn: false
  alias Oli.Repo

  require Logger

  def create() do
    case new(%{})
         |> Oban.insert() do
      {:ok, job} ->
        {:ok, job}

      e ->
        e
    end
  end

  @impl Oban.Worker
  def perform(_job) do
    execute_refresh()
  end

  @doc """
    Refreshes the part_mapping materialized view.
    Since this operation is expensive, do not use it synchronously unless neccesary.
  """
  def perform_now() do
    execute_refresh()
  end

  defp execute_refresh() do
    Repo.query("REFRESH MATERIALIZED VIEW CONCURRENTLY part_mapping")
  end
end
