defmodule Oli.Delivery.Settings.Combined do

defstruct end_date: nil,
            max_attempts: 0,
            retake_mode: :normal,
            late_submit: :allow,
            late_start: :allow,
            time_limit: 0,
            grace_period: 0,
            password: nil,
            scoring_strategy_id: 2,
            review_submission: :allow,
            feedback_mode: :allow,
            feedback_scheduled_date: nil,
            collab_space_config: nil,
            explanation_strategy: nil

  @type t() :: %__MODULE__{
          end_date: DateTime.t(),
          max_attempts: integer(),
          retake_mode: :normal | :targeted,
          late_submit: :allow | :disallow,
          late_start: :allow | :disallow,
          time_limit: integer(),
          grace_period: integer(),
          password: String.t(),
          scoring_strategy_id: integer(),
          review_submission: :allow | :disallow,
          feedback_mode: :allow | :disallow,
          feedback_scheduled_date: DateTime.t(),
          collab_space_config: Oli.Resources.Collaboration.CollabSpaceConfig.t(),
          explanation_strategy: Oli.Resources.ExplanationStrategy.t()
        }

end
