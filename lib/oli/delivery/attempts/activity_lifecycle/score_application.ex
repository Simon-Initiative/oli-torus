defmodule Oli.Delivery.Attempts.ActivityLifecycle.ScoreApplication do

  import Ecto.Query, warn: false
  alias Oli.Repo

  defstruct [:attempt_to_update, :scoring_strategy_id, :source_attempts]

  @doc """
  From the update to an activity attempt, generate the attempt update contexts
  needed to update the activity - and possibly the resource attempt.
  """
  def from_activity_attempt_evaluation(activity_attempt_guid) do

    # First query: retrieve both the activity and resource attempt, plus key
    # details about the page they are on
    %{
      activity_attempt_id: activity_attempt_id,
      resource_attempt_id: resource_attempt_id,
      resource_access_id: resource_access_id,
      activity_scoring_strategy_id: activity_scoring_strategy_id,
      page_scoring_strategy_id: page_scoring_strategy_id,
      graded: graded,
      batch_scoring: batch_scoring
    } = get_attempts_and_page_details(activity_attempt_guid)

    score_as_you_go? = graded and !batch_scoring

    case score_as_you_go? do

      # Second query: retrieve portions of all of the activity attempts for this
      # activity on this page - and the latest attempts for other
      # activities on this page

      true ->
        %{
          activity_attempt: activity_attempt,
          resource_attempt: resource_attempt,
          page_scoring_strategy_id: page_scoring_strategy_id,
        }
        {activity_attempt, page_scoring_strategy_id, []}

      false ->

        #
        %__MODULE__{
          attempt_to_update: activity_attempt,
          scoring_strategy_id: activity_scoring_strategy_id,
          source_attempts: [activity_attempt]
        }

    end



    case activity_attempt do

      %ActivityAttempt{attempt_number: 1} = activity_attempt ->

        # If this is the first activity attempt, we know the aggregate
        # score and out of will be the same as the activity attempt specific score and out of
        {activity_attempt, ScoringStrategy.get_id_by_type("best"), []}

      %ActivityAttempt{resource_attempt_id: resource_attempt_id} = activity_attempt ->

        # Now we need a couple of other things, first the scoring strategy and batch_mode from the
        # revision of the page that this activity is on, and secondly, the score and out_of for
        # all other activity attempts for this activity on this page
        other_attempts =
          from(
            ra in ResourceAttempt,
            join: a in ActivityAttempt, on: a.resource_attempt_id == ra.id,
            join: rev in Revision, on: r.id == ra.revision_id,
            where: ra.id == ^resource_attempt_id
              and a.resource_id == ^activity_attempt.resource_id
              and a.id != ^activity_attempt.id,
            select: %{
              scoring_strategy_id: rev.scoring_strategy_id,
              batch_scoring: rev.batch_scoring,
              score: a.score,
              out_of: a.out_of,
              date_evaluated: a.date_evaluated,
              attempt_guid: a.attempt_guid
            }
          )
          |> Repo.all()

        case hd(other_attempts) do
          %{batch_scoring: false} ->
            {activity_attempt, ScoringStrategy.get_id_by_type("best"), []}

          %{scoring_strategy_id: scoring_strategy_id} ->
            {activity_attempt, scoring_strategy_id, other_attempts}
        end

    end
  end


  defp get_attempts_and_page_details(activity_attempt_guid) do

    from(
      a in ActivityAttempt,
      join: ra in ResourceAttempt, on: a.resource_attempt_id == ra.id,
      join: rev in Revision, on: rev.id == a.revision_id,
      join: rev2 in Revision, on: rev2.id == ra.revision_id,
      where: a.attempt_guid == ^activity_attempt_guid,
      select: %{
        activity_attempt_id: a.id,
        resource_attempt_id: ra.id,
        resource_access_id: ra.resource_access_id,
        activity_scoring_strategy_id: rev.scoring_strategy_id,
        graded: rev2.graded,
        page_scoring_strategy_id: rev2.scoring_strategy_id,
        batch_scoring: rev2.batch_scoring
      }
    )
    |> Repo.one()
  end

end
