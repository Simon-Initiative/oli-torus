defmodule Oli.Repo.Migrations.RegistrationScope do
  use Ecto.Migration

  def change do

    alter table(:api_keys) do
      add :registration_enabled, :boolean, default: false, null: false
      add :registration_namespace, :binary
    end

    flush()

    execute "UPDATE api_keys SET registration_enabled = false;"
  end
end
