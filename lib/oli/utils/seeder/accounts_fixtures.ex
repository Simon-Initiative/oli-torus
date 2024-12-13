defmodule Oli.Utils.Seeder.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Oli.Accounts` context.
  """

  alias Oli.Repo
  alias Oli.Accounts.{Author, User, SystemRole}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      sub: UUID.uuid4(),
      given_name: "Andrew",
      family_name: "Carnegie",
      email_verified: true,
      email_confirmed_at: now
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)

    {:ok, user} =
      %User{}
      |> Ecto.Changeset.cast(attrs, [:password])
      |> hash_password()
      |> User.noauth_changeset(attrs)
      |> Repo.insert()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def unique_author_email, do: "author#{System.unique_integer()}@example.com"
  def valid_author_password, do: "hello world!"

  def valid_author_attributes(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.into(attrs, %{
      email: unique_author_email(),
      password: valid_author_password(),
      given_name: "Herbert",
      family_name: "Simon",
      system_role_id: SystemRole.role_id().author,
      email_confirmed_at: now
    })
  end

  def author_fixture(attrs \\ %{}) do
    attrs = valid_author_attributes(attrs)

    {:ok, author} =
      %Author{}
      |> Author.registration_changeset(attrs)
      |> Author.noauth_changeset(attrs)
      |> Repo.insert()

    author
  end

  defp hash_password(changeset) do
    password = Ecto.Changeset.get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> Ecto.Changeset.put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> Ecto.Changeset.delete_change(:password)
    else
      changeset
    end
  end
end
