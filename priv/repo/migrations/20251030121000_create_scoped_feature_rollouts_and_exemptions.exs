defmodule Oli.Repo.Migrations.CreateScopedFeatureRolloutsAndExemptions do
  use Ecto.Migration

  @rollout_stage_values ~w(off internal_only five_percent fifty_percent full)
  @rollout_scope_values ~w(global project section)
  @exemption_effect_values ~w(deny force_enable)

  def change do
    create table(:scoped_feature_rollouts) do
      add :feature_name, :string, null: false
      add :scope_type, :string, null: false
      add :scope_id, :bigint
      add :stage, :string, null: false
      add :rollout_percentage, :integer, null: false, default: 0
      add :updated_by_author_id, references(:authors, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create constraint(:scoped_feature_rollouts, :scoped_feature_rollouts_stage_check,
             check: "stage = ANY (ARRAY['#{Enum.join(@rollout_stage_values, "', '")}'])"
           )

    create constraint(:scoped_feature_rollouts, :scoped_feature_rollouts_scope_type_check,
             check: "scope_type = ANY (ARRAY['#{Enum.join(@rollout_scope_values, "', '")}'])"
           )

    create constraint(:scoped_feature_rollouts, :scoped_feature_rollouts_percentage_check,
             check: "rollout_percentage >= 0 AND rollout_percentage <= 100"
           )

    create unique_index(:scoped_feature_rollouts, [:feature_name, :scope_type, :scope_id],
             name: :scoped_feature_rollouts_unique_scope_index
           )

    create index(:scoped_feature_rollouts, [:feature_name, :scope_type],
             name: :scoped_feature_rollouts_feature_scope_index
           )

    create table(:scoped_feature_exemptions) do
      add :feature_name, :string, null: false
      add :publisher_id, references(:publishers, on_delete: :delete_all), null: false
      add :effect, :string, null: false
      add :note, :text
      add :updated_by_author_id, references(:authors, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create constraint(:scoped_feature_exemptions, :scoped_feature_exemptions_effect_check,
             check: "effect = ANY (ARRAY['#{Enum.join(@exemption_effect_values, "', '")}'])"
           )

    create unique_index(:scoped_feature_exemptions, [:feature_name, :publisher_id],
             name: :scoped_feature_exemptions_unique_index
           )
  end
end
