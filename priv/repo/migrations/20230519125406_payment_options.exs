defmodule Oli.Repo.Migrations.PaymentOptions do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :payment_options, :string, default: "direct_and_deferred"
    end
  end
end
