defmodule Oli.Delivery.Settings.Combined do
  @moduledoc """
  Effective settings for a resource and student.

  `removed_from_schedule` and `end_date_is_exception` describe schedule display
  precedence. They do not deactivate availability dates or assignment deadlines.
  """

  defstruct resource_id: nil,
            scheduling_type: :read_by,
            removed_from_schedule: false,
            end_date_is_exception: false,
            start_date: nil,
            end_date: nil,
            max_attempts: 0,
            retake_mode: :normal,
            assessment_mode: :traditional,
            batch_scoring: false,
            replacement_strategy: :none,
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
            explanation_strategy: nil,
            allow_hints: false,
            secure_delivery: false

  @type t() :: %__MODULE__{
          resource_id: integer(),
          scheduling_type: :due_by | :read_by | :inclass_activity,
          removed_from_schedule: boolean(),
          end_date_is_exception: boolean(),
          start_date: DateTime.t(),
          end_date: DateTime.t(),
          max_attempts: integer(),
          retake_mode: :normal | :targeted,
          assessment_mode: :traditional | :one_at_a_time,
          batch_scoring: boolean(),
          replacement_strategy: :none | :dynamic,
          late_submit: :allow | :disallow,
          late_start: :allow | :disallow,
          time_limit: integer(),
          grace_period: integer(),
          password: String.t(),
          scoring_strategy_id: integer(),
          review_submission: :allow | :disallow,
          feedback_mode: :allow | :disallow | :scheduled,
          feedback_scheduled_date: DateTime.t(),
          collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{},
          explanation_strategy: %Oli.Resources.ExplanationStrategy{},
          allow_hints: boolean(),
          secure_delivery: boolean()
        }
end
