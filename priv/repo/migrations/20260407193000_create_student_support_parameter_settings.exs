defmodule Oli.Repo.Migrations.CreateStudentSupportParameterSettings do
  use Ecto.Migration

  def change do
    create table(:student_support_parameter_settings) do
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :inactivity_days, :integer, null: false, default: 7
      add :struggling_progress_low_lt, :integer, null: false, default: 40
      add :struggling_progress_high_gt, :integer, null: false, default: 80
      add :struggling_proficiency_lte, :integer, null: false, default: 40
      add :excelling_progress_gte, :integer, null: false, default: 60
      add :excelling_proficiency_gte, :integer, null: false, default: 80

      timestamps(type: :utc_datetime)
    end

    create unique_index(:student_support_parameter_settings, [:section_id],
             name: :student_support_parameter_settings_section_id_index
           )

    create(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_inactivity_days_check,
        check: "inactivity_days IN (7, 14, 30, 90)"
      )
    )

    for field <- [
          :struggling_progress_low_lt,
          :struggling_progress_high_gt,
          :struggling_proficiency_lte,
          :excelling_progress_gte,
          :excelling_proficiency_gte
        ] do
      create(
        constraint(
          :student_support_parameter_settings,
          :"student_support_parameter_settings_#{field}_range_check",
          check: "#{field} >= 0 AND #{field} <= 100"
        )
      )
    end

    create(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_progress_order_check,
        check:
          "struggling_progress_low_lt < excelling_progress_gte AND excelling_progress_gte < struggling_progress_high_gt"
      )
    )

    create(
      constraint(
        :student_support_parameter_settings,
        :student_support_parameter_settings_proficiency_order_check,
        check: "struggling_proficiency_lte < excelling_proficiency_gte"
      )
    )
  end
end
