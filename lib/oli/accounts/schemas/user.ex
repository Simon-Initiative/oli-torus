defmodule Oli.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils, only: [maybe_name_from_given_and_family: 1]

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

    # A user may optionally be linked to an author account
    belongs_to :author, Oli.Accounts.Author

    belongs_to :institution, Oli.Institutions.Institution
    has_many :enrollments, Oli.Delivery.Sections.Enrollment
    many_to_many :platform_roles, Oli.Lti_1p3.PlatformRole, join_through: "users_platform_roles", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
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
      :institution_id,
    ])
    |> validate_required([:sub])
    |> maybe_name_from_given_and_family()
  end
end

# define implementations required for LTI 1.3 library integration
defimpl Oli.Lti_1p3.Lti_1p3_User, for: Oli.Accounts.User do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment

  def get_platform_roles(user) do
    # %User{} being passed in here is expected to have platform_roles preloaded
    user.platform_roles
  end

  def get_context_roles(user, context_id) do
    user_id = user.id
    query = from e in Enrollment, preload: [:context_roles],
      join: s in Section, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.context_id == ^context_id,
      select: e

    case Repo.one query do
      nil -> []
      enrollment -> enrollment.context_roles
    end
  end
end
