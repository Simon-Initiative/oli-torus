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

  @enforce_keys [:email_confirmed_at]
  defstruct [:email_confirmed_at, password_configured?: false]

  @type t :: %__MODULE__{
          email_confirmed_at: DateTime.t(),
          password_configured?: boolean()
        }

  @password_env "PREVIEW_DEMO_USER_PASSWORD"

  @doc "Validates the preview runtime password without hashing or retaining it in scenario state."
  @spec defaults() :: t() | nil
  def defaults do
    build(Config.preview_build?(), System.get_env(@password_env))
  end

  @doc false
  @spec build(boolean(), String.t() | nil) :: t() | nil
  def build(false, _password), do: nil

  def build(true, password) do
    defaults = %__MODULE__{
      email_confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case password do
      password when password in [nil, ""] ->
        defaults

      password ->
        validation =
          %User{}
          |> User.password_changeset(%{password: password}, hash_password: false)
          |> Ecto.Changeset.validate_length(:password, max: 72, count: :bytes)

        case validation.valid? do
          true ->
            %__MODULE__{defaults | password_configured?: true}

          false ->
            raise ArgumentError,
                  "PREVIEW_DEMO_USER_PASSWORD must satisfy the account password policy (12-72 characters, at most 72 bytes)"
        end
    end
  end

  @doc "Reads the runtime password only for seed defaults that enabled direct login."
  @spec password(t() | nil, String.t() | nil) :: String.t() | nil
  def password(defaults, fallback \\ nil)

  def password(%__MODULE__{password_configured?: true}, _fallback),
    do: System.fetch_env!(@password_env)

  def password(_defaults, fallback), do: fallback

  @doc "Confirms a new preview account and independently hashes its configured delivery-user password."
  @spec apply_defaults(Ecto.Changeset.t(), t() | nil) :: Ecto.Changeset.t()
  def apply_defaults(changeset, nil), do: changeset

  def apply_defaults(changeset, %__MODULE__{} = defaults) do
    changeset =
      Ecto.Changeset.put_change(changeset, :email_confirmed_at, defaults.email_confirmed_at)

    case {changeset.data, defaults.password_configured?} do
      {%User{}, true} ->
        changeset
        |> Ecto.Changeset.put_change(:email_verified, true)
        |> Ecto.Changeset.put_change(:independent_learner, true)
        |> User.password_changeset(%{password: password(defaults)})

      {%User{}, false} ->
        Ecto.Changeset.put_change(changeset, :email_verified, true)

      _ ->
        changeset
    end
  end
end
