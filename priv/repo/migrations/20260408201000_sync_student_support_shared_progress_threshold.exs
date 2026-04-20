defmodule Oli.Repo.Migrations.SyncStudentSupportSharedProgressThreshold do
  use Ecto.Migration

  def up do
    drop(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_progress_order_check
      )
    )

    alter table(:student_support_parameter_settings) do
      modify :excelling_progress_gte, :integer, null: false, default: 80
    end

    execute("""
    UPDATE student_support_parameter_settings
    SET excelling_progress_gte = struggling_progress_high_gt
    WHERE excelling_progress_gte <> struggling_progress_high_gt
    """)

    create(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_progress_order_check,
        check:
          "struggling_progress_low_lt < excelling_progress_gte AND excelling_progress_gte = struggling_progress_high_gt"
      )
    )
  end

  def down do
    drop(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_progress_order_check
      )
    )

    alter table(:student_support_parameter_settings) do
      modify :excelling_progress_gte, :integer, null: false, default: 60
    end

    execute("""
    UPDATE student_support_parameter_settings
    SET excelling_progress_gte =
      LEAST(
        GREATEST(struggling_progress_low_lt + 1, excelling_progress_gte),
        struggling_progress_high_gt - 1
      )
    WHERE NOT (
      struggling_progress_low_lt < excelling_progress_gte
      AND excelling_progress_gte < struggling_progress_high_gt
    )
    """)

    create(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_progress_order_check,
        check:
          "struggling_progress_low_lt < excelling_progress_gte AND excelling_progress_gte < struggling_progress_high_gt"
      )
    )
  end
end
