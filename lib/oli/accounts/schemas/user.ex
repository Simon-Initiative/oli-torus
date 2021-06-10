defmodule Oli.Accounts.User do
  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_methods: {&Bcrypt.hash_pwd_salt/1, &Bcrypt.verify_pass/2}

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

    has_many :user_identities,
             Oli.UserIdentities.UserIdentity,
             on_delete: :delete_all,
             foreign_key: :user_id

    pow_user_fields()

    # A user may optionally be linked to an author account
    belongs_to :author, Oli.Accounts.Author

    has_many :enrollments, Oli.Delivery.Sections.Enrollment

    has_many :consent_cookies, Oli.Consent.CookiesConsent

    many_to_many :platform_roles, Lti_1p3.DataProviders.EctoProvider.PlatformRole,
      join_through: "users_platform_roles",
      on_replace: :delete

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
      :guest,
      :independent_learner,
      :research_opt_out,
      :state
    ])
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
      :guest,
      :independent_learner,
      :research_opt_out,
      :state
    ])
    |> validate_required_if([:email], &is_independent_learner_not_guest/1)
    |> maybe_create_unique_sub()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name, :given_name, :family_name, :picture])
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
  end

  def is_independent_learner_not_guest(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: changes, data: data} ->
        independent_learner =
          Map.get(changes, :independent_learner) || Map.get(data, :independent_learner)

        guest = Map.get(changes, :guest) || Map.get(data, :guest)

        independent_learner && !guest

      _ ->
        false
    end
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
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted,
        select: e

    case Repo.one(query) do
      nil -> []
      enrollment -> enrollment.context_roles
    end
  end
end
