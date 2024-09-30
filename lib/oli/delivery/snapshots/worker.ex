defmodule Oli.Delivery.Snapshots.Worker do
  use Oban.Worker, queue: :snapshots, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Publishing.DeliveryResolver
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
  def perform_now(part_attempt_guids, section_slug, with_v2_support \\ true) do
    # Fetch all the necessary context information to be able to create snapshots
    results =
      from(pa in PartAttempt,
        join: aa in ActivityAttempt,
        on: pa.activity_attempt_id == aa.id,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        join: r1 in Revision,
        on: ra.revision_id == r1.id,
        join: r2 in Revision,
        on: aa.revision_id == r2.id,
        where: pa.attempt_guid in ^part_attempt_guids and pa.lifecycle_state == :evaluated,
        select: {pa, aa, ra, a, r1, r2}
      )
      |> Repo.all()

    # Determine the project id
    project_id =
      case results do
        [] ->
          Oli.Delivery.Sections.get_section_by_slug(section_slug).base_project_id

        [{_, _, _, ra, _, _} | _] ->
          Oli.Delivery.Sections.determine_which_project_id(ra.section_id, ra.resource_id)
      end

    # determine all referenced objective ids by the parts that we find
    objective_ids =
      Enum.reduce(results, MapSet.new([]), fn {pa, _, _, _, _, r}, m ->
        Enum.reduce(Map.get(r.objectives, pa.part_id, []), m, fn id, n -> MapSet.put(n, id) end)
      end)
      |> MapSet.to_list()

    objective_revisions_by_id =
      DeliveryResolver.from_resource_id(section_slug, objective_ids)
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.resource_id, e.id) end)

    # Now for each part attempt that we evaluated, create one snapshot record for every
    # attached objective:

    # Return the value of the result of the transaction as the Oban worker return value. The
    # transaction call will return  either {:ok, _} or {:error, _}. In the case of the {:ok, _} Oban
    # marks the job as completed.  In the case of an error, it scheduled it for a retry.

    case Repo.transaction(fn ->
           # First execute the v2 pipeline. If it fails it will rollback the transaction and the job will
           # be retried.
           {:ok, %Pipeline{data: attempt_group}} =
             if with_v2_support do
               Oli.Analytics.Summary.execute_analytics_pipeline(results, project_id, host_name())
             else
               {:ok, %Pipeline{data: nil}}
             end

           attrs_list =
             Enum.reduce(results, [], fn {part_attempt, _, _, _, _, activity_revision} = result,
                                         all_bulk_attrs ->
               # Look at the attached objectives for that part for that revision
               attached_objectives =
                 Map.get(activity_revision.objectives, part_attempt.part_id, [])

               bulk_attrs =
                 case attached_objectives do
                   # If there are no attached objectives, create one record recoring nils for the objectives
                   [] ->
                     [to_attrs(result, nil, nil, project_id)]

                   # Otherwise create one record for each objective, careful to dedupe in the event that
                   # somehow a part has objectives duplicated
                   objective_ids ->
                     MapSet.new(objective_ids)
                     |> MapSet.to_list()
                     |> Enum.map(fn id ->
                       to_attrs(result, id, Map.get(objective_revisions_by_id, id), project_id)
                     end)
                 end

               bulk_attrs ++ all_bulk_attrs
             end)

           Repo.insert_all(Snapshot, attrs_list, on_conflict: :nothing)

           attempt_group
         end) do
      {:ok, attempt_group} ->
        if with_v2_support and attempt_group != nil and Application.get_env(:oli, :env) != :test do
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

        {:ok, attempt_group}

      {:error, error} ->
        {:error, error}
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

  def to_attrs(
        {part_attempt, activity_attempt, resource_attempt, resource_access, resource_revision,
         activity_revision},
        objective_id,
        revision_id,
        project_id
      ) do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    hints_taken_count = length(part_attempt.hints)

    %{
      project_id: project_id,
      resource_id: resource_access.resource_id,
      user_id: resource_access.user_id,
      section_id: resource_access.section_id,
      resource_attempt_number: resource_attempt.attempt_number,
      graded: resource_revision.graded,
      activity_id: activity_attempt.resource_id,
      revision_id: activity_attempt.revision_id,
      activity_type_id: activity_revision.activity_type_id,
      attempt_number: activity_attempt.attempt_number,
      part_id: part_attempt.part_id,
      correct: part_attempt.score == part_attempt.out_of,
      score: part_attempt.score,
      out_of: part_attempt.out_of,
      hints: hints_taken_count,
      part_attempt_number: part_attempt.attempt_number,
      part_attempt_id: part_attempt.id,
      objective_id: objective_id,
      objective_revision_id: revision_id,
      inserted_at: now,
      updated_at: now
    }
  end
end
