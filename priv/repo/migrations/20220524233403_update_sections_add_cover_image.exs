defmodule Oli.Repo.Migrations.UpdateSectionsAddCoverImage do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :cover_image, :string, null: true, default: nil
    end
  end
end
