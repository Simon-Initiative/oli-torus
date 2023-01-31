defmodule Oli.Repo.Migrations.SoftScheduling do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :scheduling_type, :string, default: "read_by", null: false
      add :start_date, :date
      add :end_date, :date
    end

    create index(:section_resources, [:section_id, :end_date])
  end

end
