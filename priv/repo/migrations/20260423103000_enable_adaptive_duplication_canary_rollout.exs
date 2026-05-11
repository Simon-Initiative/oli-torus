defmodule Oli.Repo.Migrations.EnableAdaptiveDuplicationCanaryRollout do
  use Ecto.Migration

  def up do
    execute("""
    WITH existing AS (
      SELECT
        id,
        row_number() OVER (ORDER BY id) AS row_number
      FROM scoped_feature_rollouts
      WHERE feature_name = 'adaptive_duplication'
        AND scope_type = 'global'
        AND scope_id IS NULL
    ),
    deleted_duplicates AS (
      DELETE FROM scoped_feature_rollouts AS rollout
      USING existing
      WHERE rollout.id = existing.id
        AND existing.row_number > 1
    ),
    updated AS (
      UPDATE scoped_feature_rollouts AS rollout
      SET
        stage = 'full',
        rollout_percentage = 100,
        updated_at = NOW()
      FROM existing
      WHERE rollout.id = existing.id
        AND existing.row_number = 1
      RETURNING rollout.id
    )
    INSERT INTO scoped_feature_rollouts (
      feature_name,
      scope_type,
      scope_id,
      stage,
      rollout_percentage,
      inserted_at,
      updated_at
    )
    SELECT
      'adaptive_duplication',
      'global',
      NULL,
      'full',
      100,
      NOW(),
      NOW()
    WHERE NOT EXISTS (SELECT 1 FROM updated)
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
