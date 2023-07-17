defmodule Oli.Delivery.SettingsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.Combined
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.StudentException

  test "new_attempt_allowed/3 determines if a new attempt is allowed" do
    assert {:no_attempts_remaining} == Settings.new_attempt_allowed(%Combined{max_attempts: 5}, 5, [])
    assert {:blocking_gates} == Settings.new_attempt_allowed(%Combined{max_attempts: 5}, 1, [1])
    assert {:end_date_passed} == Settings.new_attempt_allowed(%Combined{max_attempts: 5, late_start: :disallow, end_date: ~U[2020-01-01 00:00:00Z]}, 1, [])
    assert {:allowed} == Settings.new_attempt_allowed(%Combined{max_attempts: 5, late_start: :allow, end_date: ~U[2020-01-01 00:00:00Z]}, 1, [])
  end

  test "was_late/2 never returns true when late submissions disallowed" do

    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 00:00:00Z],
    }
    settings = %Combined{
      late_submit: :disallow,
      time_limit: 1
    }

    refute Settings.was_late?(ra, settings, DateTime.add(ra.inserted_at, 20, :minute))

  end

  test "was_late/2 determines lateness correctly when only a time limit" do

    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 00:00:00Z],
    }
    settings_with_grace_period = %Combined{
      end_date: nil,
      time_limit: 30,
      grace_period: 5
    }

    settings_with_no_grace_period = %Combined{
      end_date: nil,
      time_limit: 30,
      grace_period: 0
    }

    refute Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 20, :minute))
    refute Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 31, :minute))
    assert Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 36, :minute))

    refute Settings.was_late?(ra, settings_with_no_grace_period, DateTime.add(ra.inserted_at, 20, :minute))
    assert Settings.was_late?(ra, settings_with_no_grace_period, DateTime.add(ra.inserted_at, 31, :minute))

  end

  test "was_late/2 determines lateness correctly when no effective due date" do

    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z],
    }
    settings_with_no_end_date = %Combined{
      end_date: nil
    }

    refute Settings.was_late?(ra, settings_with_no_end_date, DateTime.add(ra.inserted_at, 1, :minute))

  end

  test "was_late/2 determines lateness correctly when only a due date" do

    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z],
    }
    settings_with_grace_period = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      grace_period: 5
    }

    settings_with_no_grace_period = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      grace_period: 0
    }

    refute Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 59, :minute))
    refute Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 64, :minute))
    assert Settings.was_late?(ra, settings_with_grace_period, DateTime.add(ra.inserted_at, 66, :minute))

    refute Settings.was_late?(ra, settings_with_no_grace_period, DateTime.add(ra.inserted_at, 59, :minute))
    assert Settings.was_late?(ra, settings_with_no_grace_period, DateTime.add(ra.inserted_at, 61, :minute))

  end

  test "was_late/2 determines lateness correctly with both due date and time limit" do

    ra1 = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z],
    }
    settings = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      time_limit: 30
    }

    refute Settings.was_late?(ra1, settings, DateTime.add(ra1.inserted_at, 29, :minute))
    assert Settings.was_late?(ra1, settings, DateTime.add(ra1.inserted_at, 31, :minute))

    ra2 = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:45:00Z],
    }
    refute Settings.was_late?(ra2, settings, DateTime.add(ra2.inserted_at, 14, :minute))
    assert Settings.was_late?(ra2, settings, DateTime.add(ra2.inserted_at, 16, :minute))

  end

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
