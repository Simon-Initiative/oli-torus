defmodule Oli.Repo.Migrations.Pow do
  use Ecto.Migration

  def change do
    alter table(:authors) do
      modify :email, :string, null: false
      remove :provider, :string
      remove :token, :string
    end
  end
end
