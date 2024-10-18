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

    alter table(:authors) do
      # convert existing email column from varchar to citext
      modify :email, :citext
    end

    rename table(:authors), :password_hash, to: :hashed_password
    rename table(:authors), :email_confirmed_at, to: :confirmed_at

    ## unique_index(:authors, [:email]) already exists for authors, so no need to add it here

    create table(:authors_tokens) do
      add :author_id, references(:authors, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :timestamptz, updated_at: false)
    end

    create index(:authors_tokens, [:author_id])
    create unique_index(:authors_tokens, [:context, :token])
  end

  def down do
    drop unique_index(:authors_tokens, [:context, :token])
    drop index(:authors_tokens, [:author_id])

    drop table(:authors_tokens)

    rename table(:authors), :confirmed_at, to: :email_confirmed_at
    rename table(:authors), :hashed_password, to: :password_hash

    alter table(:authors) do
      modify :email, :string
    end

    drop unique_index(:users_tokens, [:context, :token])
    drop index(:users_tokens, [:user_id])

    drop table(:users_tokens)

    drop unique_index(:users, [:email])

    rename table(:users), :confirmed_at, to: :email_confirmed_at
    rename table(:users), :hashed_password, to: :password_hash

    alter table(:users) do
      modify :email, :string
    end

    execute "DROP EXTENSION IF EXISTS citext", ""
  end
end
