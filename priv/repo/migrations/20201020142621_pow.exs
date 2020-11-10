defmodule Oli.Repo.Migrations.Pow do
  use Ecto.Migration

  def change do
    # modify authors table for pow
    rename table(:authors), :first_name, to: :given_name
    rename table(:authors), :last_name, to: :family_name

    alter table(:authors) do
      modify :email, :string, null: false
      remove :provider, :string
      remove :token, :string
      remove :email_verified, :boolean

      add :name, :string
      add :picture, :string
      add :email_confirmation_token, :string
      add :email_confirmed_at, :utc_datetime
      add :unconfirmed_email, :string
    end

    create unique_index(:authors, [:email_confirmation_token])

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
