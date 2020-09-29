defmodule Oli.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string, default: ""
    field :first_name, :string, default: ""
    field :last_name, :string, default: ""
    field :user_id, :string
    field :user_image, :string

    # A user may optionally be linked to an author account
    belongs_to :author, Oli.Accounts.Author
    belongs_to :institution, Oli.Accounts.Institution
    has_many :enrollments, Oli.Delivery.Sections.Enrollment
    embeds_many :platform_roles, Oli.Lti_1p3.PlatformRole, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :user_id, :user_image, :institution_id, :author_id])
    |> validate_required([:user_id])
  end
end

defimpl Oli.Lti_1p3.Lti_1p3_User, for: Oli.Accounts.User do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment

  def get_platform_roles(user), do: user.platform_roles
  def get_context_roles(user, context_id) do
    user_id = user.id
    query = from e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.context_id == ^context_id,
      select: e.context_roles

    case Repo.one query do
      nil -> []
      context_roles -> context_roles
    end
  end
end
