defmodule Oli.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    alter table(:users) do
      # convert existing email column from varchar to citext
      modify :email, :citext
    end

    rename table(:users), :password_hash, to: :hashed_password
    rename table(:users), :email_confirmed_at, to: :confirmed_at

    create unique_index(:users, [:email])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :timestamptz, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end

  def down do
    drop unique_index(:users_tokens, [:context, :token])
    drop index(:users_tokens, [:user_id])

    drop table(:users_tokens)

    drop unique_index(:users, [:email])

    rename table(:users), :confirmed_at, to: :email_confirmed_at
    rename table(:users), :hashed_password, to: :password_hash

    alter table(:users) do
      # convert existing email column from varchar to citext
      modify :email, :string
    end

    execute "DROP EXTENSION IF EXISTS citext", ""
  end
end
