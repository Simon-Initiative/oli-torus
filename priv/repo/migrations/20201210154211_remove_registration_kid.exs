defmodule Oli.Repo.Migrations.RemoveRegistrationKid do
  use Ecto.Migration

  def change do
    alter table(:lti_1p3_registrations) do
      remove :kid, :string
    end

    create unique_index(:lti_1p3_registrations, [:issuer, :client_id])
  end
end
