defmodule Oli.Repo.Migrations.AddBypassPaywallFieldToDiscounts do
  use Ecto.Migration

  def change do
    alter table(:discounts) do
      add(:bypass_paywall, :boolean, default: false)
    end
  end
end
