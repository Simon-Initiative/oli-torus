defmodule Oli.Groups.Community do
  use Ecto.Schema
  import Ecto.Changeset

  @string_field_limit 255

  schema "communities" do
    field :name, :string
    field :description, :string
    field :key_contact, :string
    field :global_access, :boolean, default: true
    field :status, Ecto.Enum, values: [:active, :deleted], default: :active

    many_to_many :users, Oli.Accounts.User, join_through: Oli.Groups.CommunityAccount

    many_to_many :authors, Oli.Accounts.Author, join_through: Oli.Groups.CommunityAccount

    many_to_many :projects, Oli.Authoring.Course.Project,
      join_through: Oli.Groups.CommunityVisibility

    many_to_many :sections, Oli.Delivery.Sections.Section,
      join_through: Oli.Groups.CommunityVisibility,
      where: [type: {:fragment, "? = 'blueprint'"}]

    many_to_many :institutions, Oli.Institutions.Institution,
      join_through: Oli.Groups.CommunityInstitution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(community, attrs \\ %{}) do
    community
    |> cast(attrs, [:name, :description, :key_contact, :global_access, :status])
    |> validate_required([:name, :global_access, :status])
    |> unique_constraint(:name)
    |> validate_length(:name, max: @string_field_limit)
    |> validate_length(:key_contact, max: @string_field_limit)
  end
end
