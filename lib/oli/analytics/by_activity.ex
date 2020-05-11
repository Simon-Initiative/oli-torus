defmodule Oli.Analytics.ByActivity do

  import Ecto.Query, warn: false
  alias Oli.Delivery.Attempts.Snapshot
  alias Oli.Repo

  def activity_num_attempts_rel_difficulty do
    Repo.all(from snapshot in Snapshot,
      group_by: :activity,
      select: %{
        activity: snapshot.activity,
        number_of_attempts: count(snapshot.id),
        relative_difficulty: sum(
            snapshot.hints +
            fragment("if ? is false then 1 else 0 end if", snapshot.correct))
          / count(snapshot.id),
      })
  end

  # users who eventually got the activity correct
  # activity1 user1
  def activity_correctness do
    Repo.all(from snapshot in Snapshot,
      group_by: [:activity, :user],
      select: %{
        activity: snapshot.activity,
        user: snapshot.user,
        is_eventually_correct: fragment("bool_or(?)", snapshot.correct),
        is_first_try_correct: fragment("bool_or(? is true and ? == 1)", snapshot.correct, snapshot.attempt_number)
      })
  end

  # activity1 .95 .87
  # activity2 1 .95
  def activity_correctness_ratio do
    Repo.all(from correctness in activity_correctness(),
      group_by: [:activity],
      select: %{
        activity: correctness.activity,
        eventually_correct_ratio: sum(fragment("if ? is true then 1 else 0 end if", correctness.is_eventually_correct))
          / count(correctness.user),
        first_try_correct_ratio: sum(fragment("if ? is true then 1 else 0 end if", correctness.is_first_try_correct))
          / count(correctness.user)
      })
  end

end
