defmodule Oli.Repo.Migrations.AddLineItemsDomainToRegistration do
  use Ecto.Migration

  def change do
    alter table(:lti_1p3_registrations) do
      add :line_items_service_domain, :string
    end

    alter table(:pending_registrations) do
      add :line_items_service_domain, :string
    end
  end
end
