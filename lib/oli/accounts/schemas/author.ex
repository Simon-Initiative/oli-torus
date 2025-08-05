defmodule Oli.Accounts.Author do
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Utils

  alias Oli.Accounts.SystemRole

  schema "authors" do
    field :email, :string
    field :email_verified, :boolean, virtual: true
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :email_confirmed_at, :utc_datetime

    field :invitation_accepted_at, :utc_datetime

    field :name, :string
    field :given_name, :string
    field :family_name, :string
    field :picture, :string
    field :locked_at, :utc_datetime

    has_many :user_identities,
             Oli.AssentAuth.AuthorIdentity,
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
    |> cast(attrs, [
      :email,
      :password,
      :name,
      :given_name,
      :family_name,
      :picture
    ])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_required([:given_name, :family_name])
    |> default_system_role()
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Invites author.

  Only the author id will be set, and the persisted author won't have
  any password for authentication.
  (The author will set the password in the redeem invitation flow)
  """
  @spec invite_changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map(), list()) ::
          Ecto.Changeset.t()

  def invite_changeset(author, attrs, opts \\ [])

  def invite_changeset(%Ecto.Changeset{} = changeset, attrs, opts) do
    changeset
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> validate_email(opts)
    |> put_change(:system_role_id, Oli.Accounts.SystemRole.role_id().author)
  end

  def invite_changeset(user, attrs, opts) do
    user
    |> Ecto.Changeset.change()
    |> invite_changeset(attrs, opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_change(:email, &Oli.Accounts.validate_email/2)
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
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
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
  Confirms the account by setting `email_confirmed_at`.
  """
  def confirm_changeset(author) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(author, email_confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no author or the author doesn't have a password, we call
  `Bcrypt.no_author_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Oli.Accounts.Author{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, password_hash)
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
  Changeset for creating or updating authors with an author identity.
  """
  def author_identity_changeset(author, author_identity, attrs) do
    author
    |> cast(attrs, [
      :email,
      :email_verified,
      :name,
      :given_name,
      :family_name,
      :picture
    ])
    |> cast(%{user_identities: [author_identity]}, [])
    |> cast_assoc(:user_identities)
    |> unique_constraint(:email)
    |> default_system_role()
    |> maybe_name_from_given_and_family()
    |> confirm_email_if_verified()
  end

  @doc """
  Changeset for updating authors details that are not related to authentication.
  """
  def details_changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [
      :name,
      :given_name,
      :family_name,
      :picture
    ])
    |> cast_embed(:preferences)
    |> validate_required([:given_name, :family_name])
    |> default_system_role()
    |> maybe_name_from_given_and_family()
    |> confirm_email_if_verified()
  end

  @doc """
  Creates a changeset that doesn't require a current password, used for any changes to user
  that are not authentication related.
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
      :email_confirmed_at
    ])
    |> cast_embed(:preferences)
    |> validate_change(:email, &Oli.Accounts.validate_email/2)
    |> common_name_validations()
    |> unique_constraint(:email)
    |> default_system_role()
    |> maybe_hash_password([])
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that can be used by the seed script to bootstrap the admin user.
  This changeset should only be used in seed scripts or tests.
  """
  def bootstrap_admin_changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [
      :email,
      :name,
      :given_name,
      :family_name,
      :picture,
      :password,
      :system_role_id,
      :locked_at,
      :email_confirmed_at
    ])
    |> maybe_hash_password([])
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that is used in the SSO context
  """

  def sso_changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [:name, :email])
    |> default_system_role()
    |> put_email_confirmed_at()
  end

  @doc """
  Creates a changeset that is used to lock/unlock an author account
  """
  def lock_account_changeset(user_or_changeset, locked) do
    changeset = Ecto.Changeset.change(user_or_changeset)

    if locked do
      locked_at = DateTime.truncate(DateTime.utc_now(), :second)

      Ecto.Changeset.change(changeset, locked_at: locked_at)
    else
      Ecto.Changeset.change(changeset, locked_at: nil)
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

  @doc """
  Accepts an invitation.

  `:invitation_accepted_at` and `email_confirmed_at` will be updated. The password can be set,
  and the email will be marked as verified since this changeset is used for accepting email invitations
  (if they recieved the email invitation and accessed the link to accept it we can conclude that the email exists and belongs to the author).
  """
  def accept_invitation_changeset(author, attrs, opts \\ []) do
    now = Oli.DateTime.utc_now() |> DateTime.truncate(:second)

    author
    |> cast(attrs, [
      :email,
      :password,
      :given_name,
      :family_name
    ])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_email(opts)
    |> validate_password(opts)
    |> put_change(:invitation_accepted_at, now)
    |> put_change(:email_confirmed_at, now)
    |> default_system_role()
    |> maybe_name_from_given_and_family()
  end
end
