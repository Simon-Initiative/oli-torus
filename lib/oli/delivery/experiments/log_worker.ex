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
        args: %{"activity_attempt_guid" => attempt_guid, "section_slug" => section_slug}
      }) do
    perform_now(attempt_guid, section_slug)
  end

  def perform_now(attempt_guid, section_slug) do

    # Fetch the section, fail fast if experiments are not enabled, we are done
    case Oli.Delivery.Sections.get_section_by(slug: section_slug) do

      %Oli.Delivery.Sections.Section{has_experiments: true} ->

        {score, out_of, enrollment_id} =
          from(aa in ActivityAttempt,
            join: ra in ResourceAttempt,
            on: aa.resource_attempt_id == ra.id,
            join: a in ResourceAccess,
            on: ra.resource_access_id == a.id,
            join: e in Enrollment,
            on: a.section_id == e.section_id and a.user_id == e.user_id,
            where: aa.attempt_guid == ^attempt_guid,
            select: {aa.score, aa.out_of, e.id}
          )
          |> Repo.one()

        correctness = case score do
          0.0 -> 0.0
          s -> case out_of do
            0.0 -> 0.0
            o -> s / o
          end
        end

        Oli.Delivery.Experiments.log(enrollment_id, correctness)

      _ ->
        {:nothing_to_do}

    end

  end

  @doc """
  Schedule a log posting job.  If Upgrade integration is not enabled in this
  instance of the platform, do nothing.
  """
  def maybe_schedule(result, activity_attempt_guid, section_slug) do

    case Oli.Delivery.Experiments.experiments_enabled?() do
      true ->
        %{activity_attempt_guid: activity_attempt_guid, section_slug: section_slug}
        |> Oli.Delivery.Experiments.LogWorker.new()
        |> Oban.insert()

      _ ->
        true

    end

    result
  end

end
