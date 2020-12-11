defmodule Oli.Repo.Migrations.UnlinkInstitutionAuthor do
  use Ecto.Migration

  def change do
    alter table(:institutions) do
      remove :author_id, references(:authors)
      add :approved_at, :utc_datetime
    end
  end
end
