defmodule Oli.Repo.Migrations.RemoveInvitationTokenFromUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :invitation_token
    end
  end

  def down do
    alter table(:users) do
      add :invitation_token, :string
    end
  end
end
