defmodule Oli.Scenarios.DemoAccounts do
  @moduledoc """
  Supplies creation-only account defaults for preview seed execution.

  The runtime secret takes effect only in preview artifacts. Scenario account defaults
  store confirmation and login flags, never the password or a reusable password hash.
  Each new account reads the runtime secret and hashes it through its account
  changeset. Existing accounts and the bootstrap administrator are not updated.
  """

  alias Oli.Accounts.User
  alias Oli.PreviewQATools.Config

  @password_env "PREVIEW_DEMO_USER_PASSWORD"

  @doc "Validates the preview runtime password without hashing or retaining it in scenario state."
  def defaults do
    build(Config.preview_build?(), System.get_env(@password_env))
  end

  @doc false
  def build(false, _password), do: nil

  def build(true, password) do
    account = %User{
      independent_learner: false,
      email_verified: true,
      email_confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case password do
      password when password in [nil, ""] ->
        account

      password ->
        validation =
          account
          |> User.password_changeset(%{password: password}, hash_password: false)
          |> Ecto.Changeset.validate_length(:password, max: 72, count: :bytes)

        case validation.valid? do
          true ->
            %User{account | independent_learner: true}

          false ->
            raise ArgumentError,
                  "PREVIEW_DEMO_USER_PASSWORD must satisfy the account password policy (12-72 characters, at most 72 bytes)"
        end
    end
  end

  @doc "Reads the runtime password only for seed defaults that enabled direct login."
  def password(defaults, fallback \\ nil)

  def password(%User{independent_learner: true}, _fallback),
    do: System.fetch_env!(@password_env)

  def password(_defaults, fallback), do: fallback

  @doc "Applies preview confirmation and login flags to a new account changeset."
  def apply_defaults(changeset, nil), do: changeset

  def apply_defaults(changeset, %User{} = defaults) do
    changeset =
      Ecto.Changeset.put_change(changeset, :email_confirmed_at, defaults.email_confirmed_at)

    case {changeset.data, defaults.independent_learner} do
      {%User{}, true} ->
        changeset
        |> Ecto.Changeset.put_change(:email_verified, true)
        |> Ecto.Changeset.put_change(:independent_learner, true)

      {%User{}, false} ->
        Ecto.Changeset.put_change(changeset, :email_verified, true)

      _ ->
        changeset
    end
  end
end
