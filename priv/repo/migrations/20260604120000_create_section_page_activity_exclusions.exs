defmodule Oli.Repo.Migrations.CreateSectionPageActivityExclusions do
  use Ecto.Migration

  def change do
    create table(:section_page_activity_exclusions) do
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :page_resource_id, :bigint, null: false
      add :selection_id, :string
      add :kind, :string, null: false
      add :excluded_resource_id, :bigint

      timestamps(type: :utc_datetime)
    end

    create index(:section_page_activity_exclusions, [:section_id, :page_resource_id],
             name: :section_page_activity_exclusions_page_idx
           )

    create index(
             :section_page_activity_exclusions,
             [:section_id, :page_resource_id, :selection_id],
             name: :section_page_activity_exclusions_selection_idx
           )

    create unique_index(
             :section_page_activity_exclusions,
             [:section_id, :page_resource_id, :kind, :excluded_resource_id],
             name: :section_page_activity_exclusions_embedded_activity_unique_idx,
             where: "kind = 'embedded_activity'"
           )

    create unique_index(
             :section_page_activity_exclusions,
             [:section_id, :page_resource_id, :kind, :selection_id],
             name: :section_page_activity_exclusions_bank_selection_unique_idx,
             where: "kind = 'bank_selection'"
           )

    create unique_index(
             :section_page_activity_exclusions,
             [:section_id, :page_resource_id, :kind, :selection_id, :excluded_resource_id],
             name: :section_page_activity_exclusions_bank_candidate_unique_idx,
             where: "kind = 'bank_candidate'"
           )

    create constraint(
             :section_page_activity_exclusions,
             :section_page_activity_exclusions_kind_shape_check,
             check:
               "(kind = 'embedded_activity' AND selection_id IS NULL AND excluded_resource_id IS NOT NULL) OR " <>
                 "(kind = 'bank_selection' AND selection_id IS NOT NULL AND excluded_resource_id IS NULL) OR " <>
                 "(kind = 'bank_candidate' AND selection_id IS NOT NULL AND excluded_resource_id IS NOT NULL)"
           )
  end
end
