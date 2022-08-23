defmodule Oli.Repo.Migrations.UpdateSectionsTableSkipEmailVerification do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :skip_email_verification, :boolean, default: false, null: false
    end
  end
end
