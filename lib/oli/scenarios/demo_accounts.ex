defmodule Oli.Scenarios.DemoAccounts do
  @moduledoc """
  Supplies creation-only account defaults for preview seed execution.

  The runtime secret takes effect only in preview artifacts. Only a redacted account
  struct containing its validated hash enters scenario state, never the password.
  Existing accounts and the bootstrap administrator are not updated.
  """

  alias Oli.Accounts.User
  alias Oli.PreviewQATools.Config

  @doc "Builds account defaults from the preview runtime Secret, or returns nil outside preview."
  def defaults do
    build(Config.preview_build?(), System.get_env("PREVIEW_DEMO_USER_PASSWORD"))
  end

  @doc false
  def build(false, _password), do: nil

  def build(true, password) do
    account = %User{
      email_verified: true,
      email_confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case password do
      nil ->
        account

      "" ->
        account

      password ->
        # Hash once per seed run so large synthetic cohorts retain bounded hashing
        # cost. Every new demo account deliberately shares the same credential.
        case User.password_changeset(account, %{password: password}) do
          %{valid?: true} = changeset ->
            changeset
            |> Ecto.Changeset.put_change(:independent_learner, true)
            |> Ecto.Changeset.apply_changes()

          _ ->
            raise ArgumentError,
                  "PREVIEW_DEMO_USER_PASSWORD must satisfy the account password policy (12-72 characters, at most 72 bytes)"
        end
    end
  end

  @doc "Applies preview confirmation and optional credentials to a new account changeset."
  def apply_defaults(changeset, nil), do: changeset

  def apply_defaults(changeset, %User{} = defaults) do
    changeset =
      Ecto.Changeset.put_change(changeset, :email_confirmed_at, defaults.email_confirmed_at)

    changeset =
      case changeset.data do
        %User{} -> Ecto.Changeset.put_change(changeset, :email_verified, true)
        _ -> changeset
      end

    case defaults.password_hash do
      nil ->
        changeset

      hash ->
        changeset = Ecto.Changeset.put_change(changeset, :password_hash, hash)

        case changeset.data do
          %User{} -> Ecto.Changeset.put_change(changeset, :independent_learner, true)
          _ -> changeset
        end
    end
  end
end
