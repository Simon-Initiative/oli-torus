defmodule Oli.Repo.Migrations.AddPhaseFourExperimentDeliveryIndexes do
  use Ecto.Migration

  def up do
    create index(:experiment_sections, [:section_id, :experiment_id],
             name: :experiment_sections_delivery_relevance_idx
           )

    create index(:experiment_definitions, [:project_id, :id],
             where: "state = 'active'",
             name: :experiment_definitions_active_project_idx
           )
  end

  def down do
    drop index(:experiment_definitions, [:project_id, :id],
           name: :experiment_definitions_active_project_idx
         )

    drop index(:experiment_sections, [:section_id, :experiment_id],
           name: :experiment_sections_delivery_relevance_idx
         )
  end
end
