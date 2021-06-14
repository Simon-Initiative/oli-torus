defmodule Oli.Accounts.Author do
  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_methods: {&Bcrypt.hash_pwd_salt/1, &Bcrypt.verify_pass/2}

  use PowAssent.Ecto.Schema

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowEmailConfirmation, PowInvitation]

  import Ecto.Changeset
  import Oli.Utils

  alias Oli.Accounts.SystemRole

  schema "authors" do
    field :name, :string
    field :given_name, :string
    field :family_name, :string
    field :picture, :string

    has_many :user_identities,
             Oli.UserIdentities.AuthorIdentity,
             on_delete: :delete_all,
             foreign_key: :user_id

    pow_user_fields()

    embeds_one :preferences, Oli.Accounts.AuthorPreferences, on_replace: :delete
    belongs_to :system_role, Oli.Accounts.SystemRole
    has_many :users, Oli.Accounts.User

    many_to_many :projects, Oli.Authoring.Course.Project,
      join_through: Oli.Authoring.Authors.AuthorProject,
      on_replace: :delete

    many_to_many :sections, Oli.Delivery.Sections.Section,
      join_through: Oli.Delivery.Sections.AuthorSection

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(author, attrs \\ %{}) do
    author
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
    |> cast(attrs, [
      :name,
      :given_name,
      :family_name,
      :picture,
      :system_role_id
    ])
    |> cast_embed(:preferences)
    |> default_system_role()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
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
      :system_role_id
    ])
    |> cast_embed(:preferences)
    |> default_system_role()
    |> lowercase_email()
    |> maybe_name_from_given_and_family()
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name, :given_name, :family_name, :picture])
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
  end

  def invite_changeset(user_or_changeset, invited_by, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name, :given_name, :family_name])
    |> pow_invite_changeset(invited_by, attrs)
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
