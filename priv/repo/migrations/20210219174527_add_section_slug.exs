defmodule Oli.Repo.Migrations.AddSectionSlug do
  use Ecto.Migration

  def change do

    alter table(:sections) do
      add :slug, :string
    end

    create unique_index(:sections, [:slug], name: :index_slug_sections)


    drop unique_index(:lti_1p3_params, [:sub])
    rename table(:lti_1p3_params), :sub, to: :key
    create unique_index(:lti_1p3_params, [:key])
  end
end
