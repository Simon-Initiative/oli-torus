defmodule Oli.Repo.Migrations.Pow do
  use Ecto.Migration

  def change do
    # modify users table for pow
    alter table(:authors) do
      modify :email, :string, null: false
      remove :provider, :string
      remove :token, :string
    end

    # create user identities for pow_assent
    create table(:user_identities) do
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :user_id, references("authors", on_delete: :nothing)

      timestamps()
    end

    create unique_index(:user_identities, [:uid, :provider])
  end
end
