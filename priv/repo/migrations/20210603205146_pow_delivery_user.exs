defmodule Oli.Repo.Migrations.PowDeliveryUser do
  use Ecto.Migration

  def change do

    alter table(:users) do
      add :password_hash, :string
      add :email_confirmation_token, :string
      add :email_confirmed_at, :utc_datetime
      add :unconfirmed_email, :string
      add :invitation_token, :string
      add :invitation_accepted_at, :utc_datetime
      add :invited_by_id, references("users", on_delete: :nothing)
      add :independent_learner, :boolean, default: true
    end

    create unique_index(:users, [:email_confirmation_token])

    # guarantee that independent learners have unique emails
    create unique_index(:users, [:email], where: "independent_learner = true", name: :users_email_independent_learner_index)

    # rename current user_identities to author_identities
    drop unique_index(:user_identities, [:uid, :provider])
    rename table(:user_identities), to: table(:author_identities)
    create unique_index(:author_identities, [:uid, :provider])

    # create new user identities for users
    create table(:user_identities) do
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :user_id, references("users", on_delete: :nothing)

      timestamps()
    end

    create unique_index(:user_identities, [:uid, :provider])
  end
end
