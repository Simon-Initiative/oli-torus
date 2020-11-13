defmodule Oli.Repo.Migrations.Pow do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Accounts.Author

  def up do

    # create user identities for pow_assent
    create table(:user_identities) do
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :user_id, references("authors", on_delete: :nothing)

      timestamps()
    end

    create unique_index(:user_identities, [:uid, :provider])

    execute(&convert_author_providers_to_user_identities_up/0)

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

    execute(&convert_author_providers_to_user_identities_down/0)

    drop unique_index(:user_identities, [:uid, :provider])

    drop table(:user_identities)
  end

  defp convert_author_providers_to_user_identities_up() do
    flush()

    authors = Oli.Repo.all(
      from a in "authors",
        where: a.provider != "identity",
        select: %{id: a.id, provider: a.provider}
    )

    now = Timex.now()
    user_identities = Enum.map(authors, fn author ->
      %{
        provider: author.provider,
        user_id: author.id,
        uid: "pending-#{UUID.uuid4()}",
        inserted_at: now,
        updated_at: now
      }
    end)

    Oli.Repo.insert_all("user_identities", user_identities)
  end

  defp convert_author_providers_to_user_identities_down() do
    user_identities = Oli.Repo.all(
      from i in "user_identities",
        select: %{user_id: i.user_id, provider: i.provider}
    )

    Enum.each(user_identities, fn i ->
      from(a in "authors", where: a.id == ^i.user_id, select: %{id: a.id})
      |> Oli.Repo.update_all(set: [provider: i.provider])
    end)
  end
end
