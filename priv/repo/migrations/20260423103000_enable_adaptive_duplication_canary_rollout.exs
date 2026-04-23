defmodule Oli.Repo.Migrations.EnableAdaptiveDuplicationCanaryRollout do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO scoped_feature_rollouts (
      feature_name,
      scope_type,
      scope_id,
      stage,
      rollout_percentage,
      inserted_at,
      updated_at
    )
    VALUES (
      'adaptive_duplication',
      'global',
      NULL,
      'full',
      100,
      NOW(),
      NOW()
    )
    ON CONFLICT (feature_name, scope_type, scope_id)
    DO UPDATE SET
      stage = EXCLUDED.stage,
      rollout_percentage = EXCLUDED.rollout_percentage,
      updated_at = EXCLUDED.updated_at
    """)
  end

  def down do
    execute("""
    DELETE FROM scoped_feature_rollouts
    WHERE feature_name = 'adaptive_duplication'
      AND scope_type = 'global'
      AND scope_id IS NULL
    """)
  end
end
