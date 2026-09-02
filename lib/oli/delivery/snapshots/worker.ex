defmodule Oli.Delivery.Snapshots.Worker do
  use Oban.Worker, queue: :snapshots, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Analytics.Common.Pipeline
  alias Oli.Analytics.XAPI.StatementFactory
  alias Oli.Delivery.Experiments.RewardHandoff

  @moduledoc """
  An Oban worker driven snapshot creator.  Snapshot creation jobs take a section slug and a collection of
  part attempt guids as parameters and create the necessary snapshot records from that information and a
  broader context from the resource attempt hierarchy and attached objectives.

  If the job fails, it will be retried up to a total of the configured maximum attempts.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"part_attempt_guids" => part_attempt_guids, "section_slug" => section_slug}
      }) do
    perform_now(part_attempt_guids, section_slug)
  end

  @doc """
  Allows immediate execution of the snapshot creation logic. Used to bypass queueing during testing scenarios.
  """
  def perform_now(guids, section_slug, emit_fn \\ &Oli.Analytics.XAPI.emit/1)

  def perform_now([], _, _emit_fn) do
    :ok
  end

  def perform_now(part_attempt_guids, section_slug, emit_fn) when is_function(emit_fn, 1) do
    # Fetch all the necessary context information to be able to create snapshots
    results =
      from(pa in PartAttempt,
        join: aa in ActivityAttempt,
        on: pa.activity_attempt_id == aa.id,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        join: r2 in Revision,
        on: aa.revision_id == r2.id,
        where: pa.attempt_guid in ^part_attempt_guids and pa.lifecycle_state == :evaluated,
        select: {pa, aa, ra, a, r2}
      )
      |> Repo.all()

    with :ok <- record_assessment_rewards(results) do
      create_and_emit_snapshot(results, section_slug, emit_fn)
    end
  end

  defp create_and_emit_snapshot(results, section_slug, emit_fn) do
    # Determine the project id
    project_id =
      case results do
        [] ->
          Oli.Delivery.Sections.get_section_by_slug(section_slug).base_project_id

        [{_, _, _, ra, _} | _] ->
          Oli.Delivery.Sections.determine_which_project_id(ra.section_id, ra.resource_id)
      end

    case Oli.Analytics.Summary.execute_analytics_pipeline(results, project_id, host_name()) do
      {:ok, %Pipeline{data: nil}} ->
        # No evaluated part attempts found - job completes successfully without sending bundle
        :ok

      {:ok, %Pipeline{data: attempt_group}} ->
        body =
          StatementFactory.to_statements(attempt_group)
          |> Oli.Analytics.Common.to_jsonlines()

        bundle_id = create_bundle_id(attempt_group)

        partition_id = attempt_group.context.section_id

        %StatementBundle{
          body: body,
          bundle_id: bundle_id,
          partition_id: partition_id,
          category: :attempt_evaluated,
          partition: :section
        }
        |> emit_fn.()

      e ->
        e
    end
  end

  defp record_assessment_rewards(results) do
    case Enum.uniq_by(results, fn {_, _, resource_attempt, _, _} -> resource_attempt.id end) do
      [] ->
        :ok

      [{_, _, resource_attempt, _, _}] ->
        RewardHandoff.record_evaluated_resource_attempt(resource_attempt.id)

      _multiple_resource_attempts ->
        {:error, :snapshot_spans_multiple_resource_attempts}
    end
  end

  defp create_bundle_id(attempt_group) do
    guids =
      Enum.map(attempt_group.part_attempts, fn part_attempt ->
        part_attempt.attempt_guid
      end)
      |> Enum.join(",")

    :crypto.hash(:md5, guids)
    |> Base.encode16()
  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end
end
