defmodule Oli.Accounts.Author do
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Utils

  alias Oli.Accounts.SystemRole

  schema "authors" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    field :name, :string
    field :given_name, :string
    field :family_name, :string
    field :picture, :string
    field :locked_at, :utc_datetime

    has_many :user_identities,
             Oli.UserIdentities.AuthorIdentity,
             on_delete: :delete_all,
             foreign_key: :user_id

    embeds_one :preferences, Oli.Accounts.AuthorPreferences, on_replace: :delete
    belongs_to :system_role, Oli.Accounts.SystemRole
    has_many :users, Oli.Accounts.User

    many_to_many :projects, Oli.Authoring.Course.Project,
      join_through: Oli.Authoring.Authors.AuthorProject,
      on_replace: :delete

    many_to_many :sections, Oli.Delivery.Sections.Section,
      join_through: Oli.Delivery.Sections.AuthorsSections

    many_to_many :communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityAccount

    field :collaborations_count, :integer, virtual: true
    field :total_count, :integer, virtual: true
    field :community_admin_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  A author changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(author, attrs, opts \\ []) do
    author
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Oli.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A author changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(author, attrs, opts \\ []) do
    author
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A author changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(author, attrs, opts \\ []) do
    author
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(author) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(author, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no author or the author doesn't have a password, we call
  `Bcrypt.no_author_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Oli.Accounts.Author{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc """
  Creates a changeset that doesnt require a current password, used for lower risk changes to author
  (as opposed to higher risk, like password changes)
  """
  def noauth_changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [
      :email,
      :name,
      :given_name,
      :family_name,
      :picture,
      :system_role_id,
      :locked_at,
      :email_confirmed_at,
      :email_confirmation_token
    ])
    |> cast_embed(:preferences)
    |> default_system_role()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that is used in the SSO context
  """

  def sso_changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [:name, :email])
    |> default_system_role()
    |> lowercase_email()
    |> put_email_confirmed_at()
  end

  @spec lock_changeset(Ecto.Schema.t() | Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def lock_changeset(user_or_changeset) do
    changeset = Ecto.Changeset.change(user_or_changeset)
    locked_at = DateTime.truncate(DateTime.utc_now(), :second)

    case Ecto.Changeset.get_field(changeset, :locked_at) do
      nil -> Ecto.Changeset.change(changeset, locked_at: locked_at)
      _any -> Ecto.Changeset.add_error(changeset, :locked_at, "already set")
    end
  end

  defp default_system_role(changeset) do
    case changeset do
      # if changeset is valid and doesnt have a system role set, default to author
      %Ecto.Changeset{
        valid?: true,
        changes: changes,
        data: %Oli.Accounts.Author{system_role_id: nil}
      } ->
        case Map.get(changes, :system_role_id) do
          nil ->
            put_change(changeset, :system_role_id, SystemRole.role_id().author)

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end
end
