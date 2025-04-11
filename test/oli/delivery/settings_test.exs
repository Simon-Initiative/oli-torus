defmodule Oli.Delivery.SettingsTest do
  use ExUnit.Case, async: true
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.Combined
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.StudentException

  test "new_attempt_allowed/3 determines if a new attempt is allowed" do
    assert {:no_attempts_remaining} ==
             Settings.new_attempt_allowed(%Combined{max_attempts: 5}, 5, [])

    assert {:blocking_gates} ==
             Settings.new_attempt_allowed(%Combined{max_attempts: 5}, 1, [1])

    assert {:end_date_passed} ==
             Settings.new_attempt_allowed(
               %Combined{
                 max_attempts: 5,
                 late_start: :disallow,
                 end_date: ~U[2020-01-01 00:00:00Z],
                 scheduling_type: :due_by
               },
               1,
               []
             )

    assert {:before_start_date} ==
             Settings.new_attempt_allowed(
               %Combined{
                 max_attempts: 5,
                 late_start: :disallow,
                 start_date: DateTime.utc_now() |> DateTime.add(1, :day)
               },
               1,
               []
             )

    assert {:allowed} ==
             Settings.new_attempt_allowed(
               %Combined{max_attempts: 5, late_start: :allow, end_date: ~U[2020-01-01 00:00:00Z]},
               1,
               []
             )
  end

  test "was_late/2 never returns true when late submissions disallowed" do
    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 00:00:00Z]
    }

    settings = %Combined{
      late_submit: :disallow,
      time_limit: 1
    }

    refute Settings.was_late?(ra, settings, DateTime.add(ra.inserted_at, 20, :minute))
  end

  #   iex(12)> today = DateTime.utc_now
  # ~U[2025-03-27 18:52:09.691707Z]
  # iex(13)> next_week = DateTime.add(today, 7, :day)
  # ~U[2025-04-03 18:52:09.691707Z]
  # iex(14)> today < next_week
  # false
  # iex(15)> DateTime.compare(today, next_week)
  # :lt
  test "was_late/2 correctly compares datetimes" do
    today = ~U[2025-03-27 18:52:09.00Z]
    next_week = DateTime.add(today, 7, :day)

    # a bad date comparison would be `today < next week`

    ra = %ResourceAttempt{
      inserted_at: today
    }

    settings = %Combined{
      late_submit: :allow,
      time_limit: 1,
      scheduling_type: :due_by,
      end_date: next_week
    }

    # inside its logic the was_late function compares datetimes using DateTime.compare
    # and not "<" sign
    assert Settings.was_late?(ra, settings, DateTime.add(ra.inserted_at, 20, :minute))
  end

  test "was_late/2 determines lateness correctly when only a time limit" do
    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 00:00:00Z]
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

    refute Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 20, :minute)
           )

    refute Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 31, :minute)
           )

    assert Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 36, :minute)
           )

    refute Settings.was_late?(
             ra,
             settings_with_no_grace_period,
             DateTime.add(ra.inserted_at, 20, :minute)
           )

    assert Settings.was_late?(
             ra,
             settings_with_no_grace_period,
             DateTime.add(ra.inserted_at, 31, :minute)
           )
  end

  test "was_late/2 determines lateness correctly when no effective due date" do
    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z]
    }

    settings_with_no_end_date = %Combined{
      end_date: nil
    }

    refute Settings.was_late?(
             ra,
             settings_with_no_end_date,
             DateTime.add(ra.inserted_at, 1, :minute)
           )
  end

  test "was_late/2 determines lateness correctly when only a due date" do
    ra = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z]
    }

    settings_with_grace_period = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      grace_period: 5
    }

    settings_with_no_grace_period = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      grace_period: 0
    }

    refute Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 59, :minute)
           )

    refute Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 64, :minute)
           )

    assert Settings.was_late?(
             ra,
             settings_with_grace_period,
             DateTime.add(ra.inserted_at, 66, :minute)
           )

    refute Settings.was_late?(
             ra,
             settings_with_no_grace_period,
             DateTime.add(ra.inserted_at, 59, :minute)
           )

    assert Settings.was_late?(
             ra,
             settings_with_no_grace_period,
             DateTime.add(ra.inserted_at, 61, :minute)
           )
  end

  test "was_late/2 determines lateness correctly with both due date and time limit" do
    ra1 = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:00:00Z]
    }

    settings = %Combined{
      end_date: ~U[2020-01-01 02:00:00Z],
      time_limit: 30
    }

    refute Settings.was_late?(ra1, settings, DateTime.add(ra1.inserted_at, 29, :minute))
    assert Settings.was_late?(ra1, settings, DateTime.add(ra1.inserted_at, 31, :minute))

    ra2 = %ResourceAttempt{
      inserted_at: ~U[2020-01-01 01:45:00Z]
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
      assessment_mode: :traditional,
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
      assessment_mode: :one_at_a_time,
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
    assert combined.assessment_mode == :one_at_a_time
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
      assessment_mode: :traditional,
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
      assessment_mode: nil,
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
    assert combined.assessment_mode == :traditional
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

  test "check_start_date/1 returns allowed when start date is nil" do
    assert Settings.check_start_date(%Combined{start_date: nil}) == {:allowed}
  end

  test "check_start_date/1 returns allowed when start date has passed" do
    yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)
    assert Settings.check_start_date(%Combined{start_date: yesterday}) == {:allowed}
  end

  test "check_start_date/1 returns before_start_date when start date has not passed" do
    tomorrow = DateTime.utc_now() |> DateTime.add(1, :day)
    assert Settings.check_start_date(%Combined{start_date: tomorrow}) == {:before_start_date}
  end

  test "check_password/2 returns allowed when the received password is nil" do
    assert Settings.check_password(%{}, nil) == {:allowed}
  end

  test "check_password/2 returns Empty password when the received password is empty" do
    assert Settings.check_password(%{}, "") == {:empty_password}
  end

  test "check_password/2 returns allowed when the received password is equal to the actual password" do
    assert Settings.check_password(%Combined{password: "password"}, "password") == {:allowed}
  end

  test "check_password/2 returns invalid password when the received password is different from the actual password" do
    assert Settings.check_password(%Combined{password: "password"}, "bad_password") ==
             {:invalid_password}
  end

  test "update_student_exception/3 updates the given exception" do
    student_exception = insert(:student_exception, %{end_date: ~U[2024-01-10 00:00:00Z]})

    {:ok, updated_student_exception} =
      Settings.update_student_exception(student_exception, %{end_date: ~U[2024-01-09 00:00:00Z]})

    assert updated_student_exception.end_date == ~U[2024-01-09 00:00:00Z]
  end

  test "update_student_exception/3 does not update the exception if a required field is not provided" do
    student_exception = insert(:student_exception, %{end_date: nil})

    assert {:error,
            %Ecto.Changeset{
              errors: [end_date: {"can't be blank", [validation: :required]}],
              valid?: false
            }} =
             Settings.update_student_exception(student_exception, %{end_date: nil}, [:end_date])
  end

  test "get_student_exception_setting_for_all_resources/3 returns the student exception setting for all resources" do
    section = insert(:section)
    student = insert(:user)

    student_exception =
      insert(:student_exception, %{
        max_attempts: 10,
        end_date: ~U[2024-01-10 00:00:00Z],
        section: section,
        user: student
      })

    student_exception_2 =
      insert(:student_exception, %{
        max_attempts: 12,
        end_date: ~U[2024-01-10 00:00:00Z],
        section: section,
        user: student
      })

    # returns all fields
    result =
      Settings.get_student_exception_setting_for_all_resources(
        student_exception.section_id,
        student_exception.user_id
      )

    assert result |> Map.get(student_exception.resource_id) |> Map.keys() ==
             %Oli.Delivery.Settings.StudentException{} |> Map.from_struct() |> Map.keys()

    assert result[student_exception.resource_id].max_attempts == 10
    assert result[student_exception_2.resource_id].max_attempts == 12

    # only returns the requested fields
    assert %{
             student_exception.resource_id => %{max_attempts: 10},
             student_exception_2.resource_id => %{max_attempts: 12}
           } ==
             Settings.get_student_exception_setting_for_all_resources(
               student_exception.section_id,
               student_exception.user_id,
               [:max_attempts]
             )

    # returns an empty map if there are no exceptions for that section and user
    section_with_no_exceptions = insert(:section)

    assert %{} ==
             Settings.get_student_exception_setting_for_all_resources(
               section_with_no_exceptions.id,
               student.id
             )
  end
end
