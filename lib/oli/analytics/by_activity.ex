defmodule Oli.Analytics.ByActivity do

  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Repo

  def activity_num_attempts_rel_difficulty do
    from snapshot in Snapshot,
      group_by: [snapshot.activity_id],
      select: %{
        activity: snapshot.activity_id,
        number_of_attempts: count(snapshot.id),
        relative_difficulty: fragment("sum(? + case when ? is false then 1 else 0 end) / count(?)",
          snapshot.hints, snapshot.correct, snapshot.id)
      }
  end

  # users who eventually got the activity correct
  # activity1 user1
  def activity_correctness do
    from snapshot in Snapshot,
      group_by: [snapshot.activity_id, snapshot.user_id],
      select: %{
        activity: snapshot.activity_id,
        user: snapshot.user_id,
        is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
        is_first_try_correct: fragment("bool_or(? is true and ? = 1)", snapshot.correct, snapshot.attempt_number)
      }
  end

  # activity1 .95 .87
  # activity2 1 .95
  def activity_correctness_ratio do
    from correctness in activity_correctness(),
      group_by: [correctness.activity_id],
      select: %{
        activity: correctness.activity_id,
        eventually_correct_ratio: sum(fragment("case when ? is true then 1 else 0 end", correctness.is_eventually_correct))
          / count(correctness.user),
        first_try_correct_ratio: sum(fragment("case when ? is true then 1 else 0 end", correctness.is_first_try_correct))
          / count(correctness.user)
      }
  end

  def combined_query do
    Repo.all(from x in activity_num_attempts_rel_difficulty(),
      join: y in activity_correctness(),
      on: x.activity_id == y.activity_id
    )
  end

end
