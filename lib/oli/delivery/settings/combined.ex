defmodule Oli.Delivery.Settings.Combined do

  defstruct [
    :end_date,
    :max_attempts,
    :retake_mode,
    :late_submit,
    :late_start,
    :time_limit,
    :grace_period,
    :scoring_strategy,
    :review_submission,
    :feedback_mode,
    :feedback_scheduled_date,
    :collab_space_config,
    :explanation_strategy
  ]

end
