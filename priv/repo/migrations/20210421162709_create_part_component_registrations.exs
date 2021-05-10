defmodule Oli.Repo.Migrations.CreatePartComponentRegistrations do
  use Ecto.Migration

  def change do
    create table(:part_component_registrations) do
      add :slug, :string
      add :title, :string
      add :icon, :string
      add :description, :text
      add :delivery_element, :string
      add :authoring_element, :string
      add :delivery_script, :text
      add :authoring_script, :text
      add :globally_available, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:part_component_registrations, [:slug],
             name: :index_part_component_slug_registrations
           )

    create unique_index(:part_component_registrations, [:delivery_element],
             name: :index_part_component_delivery_element_registrations
           )

    create unique_index(:part_component_registrations, [:authoring_element],
             name: :index_part_component_authoring_element_registrations
           )

    create unique_index(:part_component_registrations, [:delivery_script],
             name: :index_part_component_delivery_script_registrations
           )

    create unique_index(:part_component_registrations, [:authoring_script],
             name: :index_part_component_authoring_script_registrations
           )

    create table(:part_component_registration_projects, primary_key: false) do
      timestamps(type: :timestamptz)

      add :part_component_registration_id, references(:part_component_registrations),
        primary_key: true

      add :project_id, references(:projects), primary_key: true
    end

    create index(:part_component_registration_projects, [:part_component_registration_id])
    create index(:part_component_registration_projects, [:project_id])

    create unique_index(
             :part_component_registration_projects,
             [:part_component_registration_id, :project_id],
             name: :index_part_component_registration_project
           )
  end
end
