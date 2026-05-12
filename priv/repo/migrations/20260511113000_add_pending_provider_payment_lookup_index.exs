defmodule Oli.Repo.Migrations.AddPendingProviderPaymentLookupIndex do
  use Ecto.Migration

  def change do
    create index(
             :payments,
             [:provider_type, :pending_user_id, :pending_section_id],
             where:
               "enrollment_id IS NULL AND application_date IS NULL AND type != 'invalidated'",
             name: :payments_pending_provider_lookup_index
           )
  end
end
