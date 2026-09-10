defmodule Oli.Repo.Migrations.NormalizeExperimentConditionsForMultiPointConfiguration do
  use Ecto.Migration

  def up do
    alter table(:experiment_conditions) do
      modify :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: true,
        from: references(:experiment_decision_points, on_delete: :nothing)

      modify :option_id, :string, null: true, from: :string
    end
  end

  def down do
    execute("""
    UPDATE experiment_conditions AS condition
    SET decision_point_id = mapping.decision_point_id,
        option_id = mapping.option_id
    FROM experiment_decision_point_conditions AS mapping
    WHERE mapping.condition_id = condition.id
      AND condition.decision_point_id IS NULL
      AND mapping.id = (
        SELECT MIN(first_mapping.id)
        FROM experiment_decision_point_conditions AS first_mapping
        WHERE first_mapping.condition_id = condition.id
      )
    """)

    alter table(:experiment_conditions) do
      modify :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false,
        from: references(:experiment_decision_points, on_delete: :nothing)

      modify :option_id, :string, null: false, from: :string
    end
  end
end
