defmodule Oli.Repo.Migrations.AllowTransferPaymentCodes do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:allow_transfer_payment_codes, :boolean, default: false)
    end
  end
end
