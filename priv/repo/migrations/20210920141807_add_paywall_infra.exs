defmodule Oli.Repo.Migrations.AddPaywallInfra do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:api_keys) do
      add :status, :string, default: "enabled", null: false
      add :hint, :string
      add :hash, :string
      add :payments_enabled, :boolean, default: true
      add :products_enabled, :boolean, default: true

      timestamps()
    end

    create unique_index(:api_keys, [:hash], name: :index_api_keys_hash)

    create table(:payments) do
      add :code, :bigint
      add :type, :string, default: "direct", null: false
      add :generation_date, :utc_datetime
      add :application_date, :utc_datetime
      add :amount, :map
      add(:section_id, references(:sections))
      add(:enrollment_id, references(:enrollments))

      timestamps()
    end

    create unique_index(:payments, [:code], name: :index_payments_code)
    create index(:payments, [:enrollment_id])
    create index(:payments, [:section_id])

    create table(:discounts) do
      add :type, :string, default: "percentage", null: false
      add :percentage, :float
      add :amount, :map
      add(:section_id, references(:sections))
      add :institution_id, references(:institutions)

      timestamps()
    end

    create index(:discounts, [:section_id])
    create index(:discounts, [:institution_id])

    create table(:section_visibilities) do
      add :section_id, references(:sections)
      add :institution_id, references(:institutions)

      timestamps()
    end

    create index(:section_visibilities, [:section_id])
    create index(:section_visibilities, [:institution_id])

    alter table(:sections) do
      add :type, :string, default: "enrollable", null: false
      add :visibility, :string, default: "global", null: false
      add :requires_payment, :boolean, default: false
      add :amount, :map
      add :has_grace_period, :boolean, default: false, null: false
      add :grace_period_days, :integer, default: 0, null: false
      add :grace_period_strategy, :string, default: "relative_to_section", null: false
      add(:blueprint_id, references(:sections))
    end

    create index(:sections, [:type])

    flush()

    from(p in "sections",
      where: is_nil(p.type)
    )
    |> Oli.Repo.update_all(
      set: [
        type: "enrollable",
        visibility: "global",
        requires_payment: false,
        has_grace_period: false,
        grace_period_days: 0,
        grace_period_strategy: "relative_to_section"
      ]
    )
  end
end
