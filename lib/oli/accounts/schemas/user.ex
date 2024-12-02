defmodule Oli.Accounts.User do
  use Ecto.Schema

  import Ecto.Query, warn: false
  import Ecto.Changeset
  import Oli.Utils

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :email_confirmed_at, :utc_datetime

    field :invitation_token, :string
    field :invitation_accepted_at, :utc_datetime

    # user fields are based on the openid connect core standard, most of which are provided via LTI 1.3
    # see https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims for full descriptions
    field :sub, :string
    field :name, :string
    field :given_name, :string
    field :family_name, :string
    field :middle_name, :string
    field :nickname, :string
    field :preferred_username, :string
    field :profile, :string
    field :picture, :string
    field :website, :string
    field :email_verified, :boolean
    field :gender, :string
    field :birthdate, :string
    field :zoneinfo, :string
    field :locale, :string
    field :phone_number, :string
    field :phone_number_verified, :boolean
    field :address, :string
    field :guest, :boolean, default: false
    field :independent_learner, :boolean, default: true
    field :research_opt_out, :boolean
    field :state, :map, default: %{}
    field :locked_at, :utc_datetime
    field :can_create_sections, :boolean, default: false
    field :age_verified, :boolean

    has_many :user_identities,
             Oli.AssentAuth.UserIdentity,
             on_delete: :delete_all,
             foreign_key: :user_id

    has_one :lti_params, Oli.Lti.LtiParams, on_delete: :delete_all, on_replace: :delete

    # A user may optionally be linked to an author account
    belongs_to :author, Oli.Accounts.Author

    belongs_to :invited_by, Oli.Accounts.User
    has_many :invited_users, Oli.Accounts.User, foreign_key: :invited_by_id

    has_many :enrollments, Oli.Delivery.Sections.Enrollment, on_delete: :delete_all

    has_many :consent_cookies, Oli.Consent.CookiesConsent, on_delete: :delete_all

    has_many :assistant_conversation_messages, Oli.Conversation.ConversationMessage,
      on_delete: :delete_all

    many_to_many :platform_roles, Lti_1p3.DataProviders.EctoProvider.PlatformRole,
      join_through: "users_platform_roles",
      on_replace: :delete

    many_to_many :users, Oli.Delivery.Sections.UserGroup,
      join_through: "user_groups_users",
      on_replace: :delete

    many_to_many :communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityAccount

    field :enrollments_count, :integer, virtual: true
    field :total_count, :integer, virtual: true
    field :enrollment_date, :utc_datetime, virtual: true
    field :payment_date, :utc_datetime, virtual: true
    field :payment_id, :integer, virtual: true
    field :payment, :map, virtual: true
    field :context_role_id, :integer, virtual: true
    field :enrollment, :map, virtual: true
    field :email_confirmation, :string, virtual: true

    field :enroll_after_email_confirmation, :string, virtual: true

    embeds_one :preferences, Oli.Accounts.UserPreferences, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

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
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :password,
      :given_name,
      :family_name,
      :picture,
      :guest
    ])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_email(opts)
    |> validate_password(opts)
    |> put_change(:independent_learner, true)
    |> maybe_create_unique_sub()
    |> maybe_name_from_given_and_family()
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
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique([:email], Oli.Repo,
        message: "Email has already been taken by another independent learner",
        query: from(u in Oli.Accounts.User, where: u.independent_learner == true)
      )
      |> unique_constraint(:email,
        name: :users_email_independent_learner_index,
        message: "Email has already been taken by another independent learner"
      )
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `email_confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, email_confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Oli.Accounts.User{password_hash: password_hash}, password)
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
  Changeset for creating or updating users with a user identity.
  """
  def user_identity_changeset(user_or_changeset, user_identity, attrs) do
    user_or_changeset
    |> cast(attrs, [
      :sub,
      :email,
      :email_verified,
      :name,
      :given_name,
      :family_name,
      :middle_name,
      :nickname,
      :preferred_username,
      :profile,
      :picture,
      :website,
      :gender,
      :birthdate,
      :zoneinfo,
      :locale,
      :phone_number,
      :phone_number_verified,
      :address
    ])
    |> cast(%{user_identities: [user_identity]}, [])
    |> cast_assoc(:user_identities)
    |> put_change(:independent_learner, true)
    |> put_change(:guest, false)
    |> unique_constraint(:email, name: :users_email_independent_learner_index)
    |> maybe_create_unique_sub()
    |> maybe_name_from_given_and_family()
    |> confirm_email_if_verified()
  end

  @doc """
  Changeset for updating user details that are not related to authentication.
  """
  def details_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :name,
      :given_name,
      :family_name,
      :middle_name,
      :nickname,
      :preferred_username,
      :profile,
      :picture,
      :website,
      :gender,
      :birthdate,
      :zoneinfo,
      :locale,
      :phone_number,
      :address,
      :research_opt_out
    ])
    |> cast_embed(:preferences)
    |> validate_required([:given_name, :family_name])
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that doesn't require a current password, used for any changes to user
  that are not authentication related.
  """
  def noauth_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :sub,
      :email,
      :email_verified,
      :email_confirmed_at,
      :name,
      :given_name,
      :family_name,
      :middle_name,
      :nickname,
      :preferred_username,
      :profile,
      :picture,
      :website,
      :gender,
      :birthdate,
      :zoneinfo,
      :locale,
      :phone_number,
      :phone_number_verified,
      :address,
      :author_id,
      :guest,
      :independent_learner,
      :research_opt_out,
      :state,
      :can_create_sections,
      :age_verified
    ])
    |> cast_embed(:preferences)
    |> validate_email_if(&is_independent_learner_and_not_guest/1)
    |> maybe_create_unique_sub()
    |> maybe_name_from_given_and_family()
  end

  defp validate_email_if(changeset, condition) do
    if condition.(changeset) do
      validate_email(changeset, [])
    else
      changeset
    end
  end

  @doc """
  Creates a changeset used by LTI launch to update user information.
  """
  def external_user_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :sub,
      :name,
      :given_name,
      :family_name,
      :middle_name,
      :nickname,
      :preferred_username,
      :profile,
      :picture,
      :website,
      :email,
      :email_verified,
      :gender,
      :birthdate,
      :zoneinfo,
      :locale,
      :phone_number,
      :phone_number_verified,
      :address,
      :author_id,
      :guest,
      :independent_learner,
      :research_opt_out,
      :state,
      :locked_at,
      :email_confirmed_at,
      :can_create_sections,
      :age_verified
    ])
    |> cast_embed(:preferences)
    |> maybe_create_unique_sub()
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that if configured, runs the age check validation.
  Used on user creation through frontend form.
  """
  def verification_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :sub,
      :name,
      :given_name,
      :family_name,
      :middle_name,
      :nickname,
      :preferred_username,
      :profile,
      :picture,
      :website,
      :email,
      :email_verified,
      :email_confirmation,
      :gender,
      :birthdate,
      :zoneinfo,
      :locale,
      :phone_number,
      :phone_number_verified,
      :address,
      :author_id,
      :guest,
      :independent_learner,
      :research_opt_out,
      :state,
      :locked_at,
      :email_confirmed_at,
      :can_create_sections,
      :age_verified
    ])
    |> validate_required_if([:email], &is_independent_learner_and_not_guest/1)
    |> validate_acceptance_if(
      :age_verified,
      &is_age_verification_enabled/1,
      "You must verify you are old enough to access our site in order to continue"
    )
    |> unique_constraint(:email, name: :users_email_independent_learner_index)
    |> maybe_create_unique_sub()
    |> validate_email_confirmation()
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that is used to lock/unlock a user account
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

  def is_independent_learner_and_not_guest(%{changes: changes, data: data} = _changeset) do
    independent_learner =
      Map.get(changes, :independent_learner) || Map.get(data, :independent_learner)

    guest = Map.get(changes, :guest) || Map.get(data, :guest)

    independent_learner && !guest
  end

  defp validate_email_confirmation(changeset) do
    changeset = Ecto.Changeset.update_change(changeset, :email_confirmation, &String.downcase/1)

    if Ecto.Changeset.get_field(changeset, :email) !=
         Ecto.Changeset.get_field(changeset, :email_confirmation) do
      Ecto.Changeset.add_error(changeset, :email_confirmation, "does not match Email")
    else
      changeset
    end
  end

  defp is_age_verification_enabled(_changeset),
    do: Application.fetch_env!(:oli, :age_verification)[:is_enabled] == "true"

  @doc """
  Invites user.

  A unique `:invitation_token` will be generated, and `invited_by` association
  will be set. Only the user id will be set, and the persisted user won't have
  any password for authentication.
  """
  def invite_changeset(user, invited_by, attrs) do
    # MER-4068 TODO
    throw("Not implemented")
  end

  @doc """
  Accepts an invitation.

  `:invitation_accepted_at` will be updated. The password can be set, and the
  user id updated.
  """
  def accept_invitation_changeset(user, attrs) do
    # MER-4068 TODO
    throw("Not implemented")
  end
end

# define implementations required for LTI 1.3 library integration
defimpl Lti_1p3.Tool.Lti_1p3_User, for: Oli.Accounts.User do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment

  def get_platform_roles(user) do
    # %User{} being passed in here is expected to have platform_roles preloaded
    user.platform_roles
  end

  def get_context_roles(user, section_slug) do
    user_id = user.id

    query =
      from e in Enrollment,
        preload: [:context_roles],
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active,
        select: e

    case Repo.one(query) do
      nil -> []
      enrollment -> enrollment.context_roles
    end
  end
end
