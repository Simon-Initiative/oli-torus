defmodule Oli.Repo.Migrations.Pow do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def up do

    # create user identities for pow_assent
    create table(:user_identities) do
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :user_id, references("authors", on_delete: :nothing)

      timestamps()
    end

    create unique_index(:user_identities, [:uid, :provider])

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

    flush()

    # populate all authors names using given_name and family_name if name is nil
    authors = Oli.Repo.all(
      from a in "authors",
        where: is_nil(a.name),
        select: %{id: a.id, given_name: a.given_name, family_name: a.family_name}
    )

    Enum.each(authors, fn author ->
      from(a in "authors", where: a.id == ^author.id)
      |> Oli.Repo.update_all(set: [name: "#{author.given_name} #{author.family_name}"])
    end)

    # populate all users names using given_name and family_name if name is nil
    users = Oli.Repo.all(
      from u in "users",
        where: is_nil(u.name),
        select: %{id: u.id, given_name: u.given_name, family_name: u.family_name}
    )

    Enum.each(users, fn user ->
      from(u in "users", where: u.id == ^user.id)
      |> Oli.Repo.update_all(set: [name: "#{user.given_name} #{user.family_name}"])
    end)
  end

  def down do

    drop unique_index(:authors, [:email_confirmation_token])

    alter table(:authors) do
      modify :email, :string
      add :provider, :string
      add :token, :string
      add :email_verified, :boolean

      remove :name, :string
      remove :picture, :string
      remove :email_confirmation_token, :string
      remove :email_confirmed_at, :utc_datetime
      remove :unconfirmed_email, :string
    end

    rename table(:authors), :given_name, to: :first_name
    rename table(:authors), :family_name, to: :last_name

    drop unique_index(:user_identities, [:uid, :provider])

    drop table(:user_identities)
  end

end
