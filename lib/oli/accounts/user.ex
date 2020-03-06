defmodule Oli.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :provider, :string
    field :token, :string
    field :password, :string
    field :email_verified, :boolean

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :provider, :token, :password, :email_verified])
    |> validate_required([:email, :first_name, :last_name, :provider])
    |> validate_length(:password, min: 6)
    |> validate_password_confirmation(attrs)
    |> hash_password()
    |> unique_constraint(:email)
  end

  defp validate_password_confirmation(changeset, attrs) do
    case {changeset, attrs} do
      {%Ecto.Changeset{valid?: true, changes: %{ password: password }}, %{ password_confirmation: password_confirmation }} ->
        case password == password_confirmation do
          true -> changeset
          _ -> add_error(changeset, :password_confirmation, "Password and confirm must match")
        end
      _ ->
        changeset
    end
  end

  defp hash_password(changeset) do
    case changeset do
      # if changeset is valid and has a password, we want to convert it to a hash
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password, Bcrypt.hash_pwd_salt(pass))
      _ ->
        changeset
    end
  end
end
