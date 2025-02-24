defmodule Oli.Repo.Migrations.AddStatusInAuthorsProjects do
  use Ecto.Migration

  def change do
    alter table(:authors_projects) do
      add :status, :string, default: "accepted"
    end
  end
end
