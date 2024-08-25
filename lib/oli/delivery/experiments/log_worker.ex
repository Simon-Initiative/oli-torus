defmodule Oli.Delivery.Experiments.LogWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Delivery.Sections.Enrollment

  @moduledoc """
  Oban job that posts Upgrade log messages for evaluated activity attempts in courses that contain
  an experiment.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"activity_attempt_guid" => attempt_guid}
      }) do
    perform_now(attempt_guid)
  end

  def perform_now(attempt_guid) do
    {score, out_of, enrollment_id, section_id} =
      from(aa in ActivityAttempt,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        join: e in Enrollment,
        on: a.section_id == e.section_id and a.user_id == e.user_id,
        where: aa.attempt_guid == ^attempt_guid,
        select: {aa.score, aa.out_of, e.id, e.section_id}
      )
      |> Repo.one()

    project_slug =
      from(s in Oli.Delivery.Sections.Section,
        join: p in Oli.Authoring.Course.Project,
        on: s.base_project_id == p.id,
        where: s.id == ^section_id,
        select: p.slug
      )
      |> Repo.one()

    correctness =
      case score do
        score when score in [+0.0, -0.0] ->
          0.0

        s ->
          case out_of do
            out_of when out_of in [+0.0, -0.0] ->
              0.0

            o ->
              try do
                s / o
              rescue
                ArithmeticError ->
                  0.0
              end
          end
      end

    Oli.Delivery.Experiments.log(enrollment_id, correctness, project_slug)
  end

  @doc """
  Schedule a log posting job.  If Upgrade integration is not enabled in this
  instance of the platform, do nothing.
  """
  def maybe_schedule(result, activity_attempt_guid, section_slug) do
    case Oli.Delivery.Experiments.experiments_enabled?() do
      true ->
        case from(s in Oli.Delivery.Sections.Section,
               where: s.slug == ^section_slug,
               select: s.has_experiments
             )
             |> Repo.one() do
          true ->
            %{activity_attempt_guid: activity_attempt_guid}
            |> Oli.Delivery.Experiments.LogWorker.new()
            |> Oban.insert()

          _ ->
            true
        end

      _ ->
        true
    end

    result
  end
end
