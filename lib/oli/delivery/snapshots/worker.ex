defmodule Oli.Delivery.Snapshots.Worker do
  use Oban.Worker, queue: :snapshots, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Resources.Revision
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Analytics.Common.Pipeline
  alias Oli.Analytics.XAPI.StatementFactory
  alias Oli.LearningModel
  alias Oli.LearningModel.LktAoa.BatchResult

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
  def perform_now(guids, section_slug, unused \\ true)

  def perform_now([], _, _unused) do
    :ok
  end

  def perform_now(part_attempt_guids, section_slug, _unused) do
    case Sections.get_section_by_slug(section_slug) do
      nil -> {:error, {:section_not_found, section_slug}}
      section -> perform_for_section(part_attempt_guids, section)
    end
  end

  defp perform_for_section(part_attempt_guids, section) do
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

    # Determine the project id
    project_id =
      case results do
        [] ->
          section.base_project_id

        [{_, _, _, ra, _} | _] ->
          Sections.determine_which_project_id(ra.section_id, ra.resource_id)
      end

    attempt_group = AttemptGroup.from_attempt_summary(results, project_id, host_name())

    # LKT-AOA is applied before summary/xAPI writes only for Sections pinned to
    # the new model, so existing :naive Sections do not pay the LKT calculation
    # or telemetry cost. When it does run, downstream failures can safely retry
    # through the exact attempt-claim projection instead of double applying
    # learner state. The AttemptGroup is intentionally built once and reused so
    # learning model, summaries, and xAPI share the same evaluated attempt set.
    with {:ok, _learning_model_result} <- apply_learning_model(section, attempt_group),
         {:ok, %Pipeline{} = pipeline} <- Summary.execute_analytics_pipeline(attempt_group) do
      case pipeline.data do
        nil ->
          # No evaluated part attempts found - job completes successfully without sending bundle.
          :ok

        %AttemptGroup{} = attempt_group ->
          emit_xapi(attempt_group)
      end
    else
      e -> e
    end
  end

  defp apply_learning_model(%{learning_model_version: :lkt_aoa} = section, attempt_group),
    do: LearningModel.apply_evaluated_attempts(section, attempt_group)

  defp apply_learning_model(_section, nil), do: {:ok, BatchResult.new(:noop)}

  defp apply_learning_model(_section, %AttemptGroup{} = attempt_group) do
    {:ok,
     BatchResult.new(:skipped, input_attempt_count: length(attempt_group.part_attempts || []))}
  end

  defp emit_xapi(attempt_group) do
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
    |> Oli.Analytics.XAPI.emit()
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
