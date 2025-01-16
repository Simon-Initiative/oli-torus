defmodule Oli.Repo.Migrations.RemoveInvitationTokenFromAuthors do
  use Ecto.Migration

  def up do
    alter table(:authors) do
      remove :invitation_token
    end
  end

  def down do
    alter table(:authors) do
      add :invitation_token, :string
    end
  end
end
