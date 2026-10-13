defmodule Oli.Repo.Migrations.RemoveConfidenceFromLearningStates do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    drop constraint(:learning_states, :learning_states_confidence_probability_range)

    alter table(:learning_states) do
      remove :confidence
    end
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:learning_states) do
      add :confidence, :float, null: false, default: 0.0
    end

    # Restore confidence for the previous application using retained evidence and
    # the effective Hill parameters, rather than leave existing learners at zero.
    # PostgreSQL raises on float underflow, so clamp negligible tails in log space.
    execute(fn ->
      config = Application.fetch_env!(:oli, :lkt_aoa)
      midpoint = Keyword.fetch!(config, :confidence_midpoint)
      steepness = Keyword.fetch!(config, :confidence_steepness)

      repo().query!(
        """
        UPDATE learning_states
        SET confidence = CASE
          WHEN unique_activity_part_count = 0 THEN 0.0
          WHEN unique_activity_part_count = $1::float8 THEN 0.5
          WHEN $2::float8 > 700.0 /
            NULLIF(abs(ln(unique_activity_part_count::float8) - ln($1::float8)), 0.0)
          THEN CASE WHEN unique_activity_part_count < $1::float8 THEN 0.0 ELSE 1.0 END
          WHEN unique_activity_part_count <= $1::float8 THEN
            exp((ln(unique_activity_part_count::float8) - ln($1::float8)) * $2::float8) /
              (1.0 + exp((ln(unique_activity_part_count::float8) - ln($1::float8)) * $2::float8))
          ELSE
            1.0 / (1.0 + exp((ln($1::float8) - ln(unique_activity_part_count::float8)) * $2::float8))
        END
        """,
        [midpoint, steepness]
      )
    end)

    create constraint(:learning_states, :learning_states_confidence_probability_range,
             check: "confidence >= 0.0 AND confidence <= 1.0"
           )
  end
end
