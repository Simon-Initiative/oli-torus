defmodule Oli.Repo.Migrations.RemoveAlgorithmFromExperimentDecisionPoints do
  use Ecto.Migration

  def up do
    drop constraint(:experiment_decision_points, :experiment_decision_points_algorithm_check)

    alter table(:experiment_decision_points) do
      remove :algorithm
    end
  end

  def down do
    alter table(:experiment_decision_points) do
      add :algorithm, :string, null: false, default: "weighted_random"
    end

    execute("""
    UPDATE experiment_decision_points AS decision_point
    SET algorithm = experiment.algorithm
    FROM experiment_definitions AS experiment
    WHERE decision_point.experiment_id = experiment.id
    """)

    create constraint(:experiment_decision_points, :experiment_decision_points_algorithm_check,
             check: "algorithm = ANY (ARRAY['weighted_random', 'thompson_sampling'])"
           )
  end
end
