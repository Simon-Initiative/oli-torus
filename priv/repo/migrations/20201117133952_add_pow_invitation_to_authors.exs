defmodule Oli.Repo.Migrations.AddPowInvitationToAuthors do
  use Ecto.Migration

  def change do
    alter table(:authors) do
      add :invitation_token, :string
      add :invitation_accepted_at, :utc_datetime
      add :invited_by_id, references("authors", on_delete: :nothing)
    end

    create unique_index(:authors, [:invitation_token])
  end
end
