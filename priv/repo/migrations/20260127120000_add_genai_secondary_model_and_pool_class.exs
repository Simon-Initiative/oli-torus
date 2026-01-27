defmodule Oli.Repo.Migrations.AddGenaiSecondaryModelAndPoolClass do
  use Ecto.Migration

  def up do
    alter table(:completions_service_configs) do
      add :secondary_model_id, references(:registered_models, on_delete: :nothing), null: true
    end

    create index(:completions_service_configs, [:secondary_model_id])

    alter table(:registered_models) do
      add :pool_class, :string, null: false, default: "slow"
      add :max_concurrent, :integer
    end

    create constraint(:registered_models, :max_concurrent_non_negative,
             check: "max_concurrent IS NULL OR max_concurrent >= 0"
           )
  end

  def down do
    drop constraint(:registered_models, :max_concurrent_non_negative)

    alter table(:registered_models) do
      remove :pool_class
      remove :max_concurrent
    end

    drop index(:completions_service_configs, [:secondary_model_id])

    alter table(:completions_service_configs) do
      remove :secondary_model_id
    end
  end
end
