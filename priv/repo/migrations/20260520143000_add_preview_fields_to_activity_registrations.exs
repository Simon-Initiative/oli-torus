defmodule Oli.Repo.Migrations.AddPreviewFieldsToActivityRegistrations do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :preview_script, :string
      add :preview_element, :string
    end

    create unique_index(:activity_registrations, [:preview_script],
             where: "preview_script IS NOT NULL"
           )

    create unique_index(:activity_registrations, [:preview_element],
             where: "preview_element IS NOT NULL"
           )
  end
end
