defmodule Oli.Delivery.Snapshots.Worker do
  use Oban.Worker, queue: :snapshots, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  import Oli.Delivery.Snapshots.Utils

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
  def perform_now(part_attempt_guids, section_slug) do
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
        where: pa.attempt_guid in ^part_attempt_guids,
        select: {pa, aa, ra, a, r1, r2}
      )
      |> Repo.all()

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
    Repo.transaction(fn ->
      Enum.each(results, fn {part_attempt, _, _, _, _, activity_revision} = result ->
        # Look at the attached objectives for that part for that revision
        attached_objectives = Map.get(activity_revision.objectives, part_attempt.part_id, [])

        case attached_objectives do
          # If there are no attached objectives, create one record recoring nils for the objectives
          [] ->
            to_attrs(result, nil, nil)
            |> create_snapshot()

          # Otherwise create one record for each objective
          objective_ids ->
            attrs_list =
              Enum.map(objective_ids, fn id ->
                to_attrs(result, id, Map.get(objective_revisions_by_id, id))
              end)

            Repo.insert_all(Snapshot, attrs_list)
        end
      end)
    end)
  end

  def to_attrs(
        {part_attempt, activity_attempt, resource_attempt, resource_access, resource_revision,
         activity_revision},
        objective_id,
        revision_id
      ) do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    %{
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
      hints: length(part_attempt.hints),
      part_attempt_number: part_attempt.attempt_number,
      part_attempt_id: part_attempt.id,
      objective_id: objective_id,
      objective_revision_id: revision_id,
      inserted_at: now,
      updated_at: now
    }
  end
end
