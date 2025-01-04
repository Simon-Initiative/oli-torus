defmodule Oli.Accounts.User do
  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_verify: {&Bcrypt.hash_pwd_salt/1, &Bcrypt.verify_pass/2}

  use PowAssent.Ecto.Schema

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowEmailConfirmation, PowInvitation]

  import Ecto.Changeset
  import Oli.Utils

  schema "users" do
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
    field :email, :string
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
             Oli.UserIdentities.UserIdentity,
             on_delete: :delete_all,
             foreign_key: :user_id

    pow_user_fields()

    # A user may optionally be linked to an author account and Institution
    belongs_to :author, Oli.Accounts.Author
    field :lti_institution_id, :integer, default: nil

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

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
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
      :lti_institution_id,
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
    |> validate_required_if([:email], &is_independent_learner_not_guest/1)
    |> unique_constraint(:email, name: :users_email_independent_learner_index)
    |> maybe_create_unique_sub()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  @doc """
  Creates a changeset that doesnt require a current password, used for lower risk changes to user
  (as opposed to higher risk, like password changes)
  """
  def noauth_changeset(user, attrs \\ %{}) do
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
      :lti_institution_id,
      :guest,
      :independent_learner,
      :research_opt_out,
      :state,
      :locked_at,
      :email_confirmed_at,
      :email_confirmation_token,
      :can_create_sections,
      :age_verified
    ])
    |> cast_embed(:preferences)
    |> validate_required_if([:email], &is_independent_learner_not_guest/1)
    |> maybe_create_unique_sub()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  def update_changeset_for_admin(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:given_name, :family_name, :independent_learner, :can_create_sections, :email])
    |> validate_required([:given_name, :family_name])
    |> maybe_name_from_given_and_family()
    |> lowercase_email()
    |> pow_user_id_field_changeset(attrs)
    |> unique_constraint(:email,
      name: :users_email_independent_learner_index,
      message: "Email has already been taken by another independent learner"
    )
  end

  @doc """
  Creates a changeset that is used to update a user's profile
  """

  def update_changeset(user, attrs \\ %{}) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [:given_name, :family_name, :email])
    |> validate_required_if([:email], &is_independent_learner_not_guest/1)
    |> unique_constraint(:email, name: :users_email_independent_learner_index)
    |> maybe_create_unique_sub()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  def invite_changeset(user_or_changeset, invited_by, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name, :given_name, :family_name])
    |> pow_invite_changeset(invited_by, attrs)
  end

  @doc """
  Creates a changeset that if configured, runs the age check validation.
  Used on user creation through frontend form.
  """
  def verification_changeset(user, attrs \\ %{}) do
    user
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
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
      :lti_institution_id,
      :guest,
      :independent_learner,
      :research_opt_out,
      :state,
      :locked_at,
      :email_confirmed_at,
      :can_create_sections,
      :age_verified
    ])
    |> validate_required_if([:email], &is_independent_learner_not_guest/1)
    |> validate_acceptance_if(
      :age_verified,
      &is_age_verification_enabled/1,
      "You must verify you are old enough to access our site in order to continue"
    )
    |> unique_constraint(:email, name: :users_email_independent_learner_index)
    |> maybe_create_unique_sub()
    |> lowercase_email()
    |> validate_email_confirmation()
    |> maybe_name_from_given_and_family()
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name, :given_name, :family_name, :picture])
    |> maybe_create_unique_sub()
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
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

  def is_independent_learner_not_guest(%{changes: changes, data: data} = _changeset) do
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
        where: e.user_id == ^user_id and s.slug == ^section_slug,
        select: e

    case Repo.one(query) do
      nil -> []
      enrollment -> enrollment.context_roles
    end
  end
end
