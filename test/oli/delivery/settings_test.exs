defmodule Oli.Delivery.SettingsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Settings
  alias Oli.Resources.Revision
  alias Oli.Delivery.Settings.StudentException

  test "combine/3 honors the inline -1 for max_attempts" do

    revision = %Revision{
      max_attempts: 5
    }
    sr = %SectionResource{
      max_attempts: -1
    }
    se = %StudentException{
      max_attempts: nil
    }

    assert Settings.combine(revision, sr, se).max_attempts == 5

  end

  test "combine/3 honors student exceptions" do

    revision = %Revision{
      max_attempts: 5
    }
    sr = %SectionResource{
      end_date: nil,
      max_attempts: 10,
      retake_mode: :normal,
      late_submit: :allow,
      late_start: :allow,
      time_limit: 20,
      grace_period: 1,
      scoring_strategy_id: 2,
      review_submission: :allow,
      feedback_mode: :allow,
      feedback_scheduled_date: nil,
      collab_space_config: 11,
      explanation_strategy: 12
    }
    se = %StudentException{
      end_date: ~U[2019-01-01 00:00:00Z],
      max_attempts: 1,
      retake_mode: :targeted,
      late_submit: :disallow,
      late_start: :disallow,
      time_limit: 30,
      grace_period: 5,
      scoring_strategy_id: 1,
      review_submission: :disallow,
      feedback_mode: :scheduled,
      feedback_scheduled_date: ~U[2021-01-01 00:00:00Z],
      collab_space_config: 2,
      explanation_strategy: 3
    }

    combined = Settings.combine(revision, sr, se)
    assert combined.end_date == ~U[2019-01-01 00:00:00Z]
    assert combined.max_attempts == 1
    assert combined.retake_mode == :targeted
    assert combined.late_submit == :disallow
    assert combined.late_start == :disallow
    assert combined.time_limit == 30
    assert combined.grace_period == 5
    assert combined.scoring_strategy_id == 1
    assert combined.review_submission == :disallow
    assert combined.feedback_mode == :scheduled
    assert combined.feedback_scheduled_date == ~U[2021-01-01 00:00:00Z]
    assert combined.collab_space_config == 2
    assert combined.explanation_strategy == 3

  end

  test "combine/3 honors nils in student exceptions" do

    revision = %Revision{
      max_attempts: 5
    }
    sr = %SectionResource{
      end_date: nil,
      max_attempts: 10,
      retake_mode: :normal,
      late_submit: :allow,
      late_start: :allow,
      time_limit: 20,
      grace_period: 1,
      scoring_strategy_id: 2,
      review_submission: :allow,
      feedback_mode: :allow,
      feedback_scheduled_date: nil,
      collab_space_config: 11,
      explanation_strategy: 12
    }

    # set :retake_mode to be nil
    se = %StudentException{
      end_date: ~U[2019-01-01 00:00:00Z],
      max_attempts: 1,
      retake_mode: nil,
      late_submit: :disallow,
      late_start: :disallow,
      time_limit: 30,
      grace_period: 5,
      scoring_strategy_id: 1,
      review_submission: :disallow,
      feedback_mode: :scheduled,
      feedback_scheduled_date: ~U[2021-01-01 00:00:00Z],
      collab_space_config: 2,
      explanation_strategy: 3
    }

    combined = Settings.combine(revision, sr, se)
    assert combined.end_date == ~U[2019-01-01 00:00:00Z]
    assert combined.max_attempts == 1
    assert combined.retake_mode == :normal
    assert combined.late_submit == :disallow
    assert combined.late_start == :disallow
    assert combined.time_limit == 30
    assert combined.grace_period == 5
    assert combined.scoring_strategy_id == 1
    assert combined.review_submission == :disallow
    assert combined.feedback_mode == :scheduled
    assert combined.feedback_scheduled_date == ~U[2021-01-01 00:00:00Z]
    assert combined.collab_space_config == 2
    assert combined.explanation_strategy == 3

  end

end
