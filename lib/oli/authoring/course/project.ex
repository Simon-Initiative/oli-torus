defmodule Oli.Authoring.Course.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  @derive {Phoenix.Param, key: :slug}
  schema "projects" do
    field :description, :string
    field :slug, :string
    field :title, :string
    field :version, :string
    field :visibility, Ecto.Enum, values: [:authors, :selected, :global], default: :authors
    field :status, Ecto.Enum, values: [:active, :deleted], default: :active
    field :allow_duplication, :boolean, default: false

    belongs_to :parent_project, Oli.Authoring.Course.Project, foreign_key: :project_id
    belongs_to :family, Oli.Authoring.Course.Family
    many_to_many :authors, Oli.Accounts.Author, join_through: Oli.Authoring.Authors.AuthorProject

    many_to_many :resources, Oli.Resources.Resource,
      join_through: Oli.Authoring.Course.ProjectResource

    many_to_many :activity_registrations, Oli.Activities.ActivityRegistration,
      join_through: Oli.Activities.ActivityRegistrationProject

    many_to_many :part_component_registrations, Oli.PartComponents.PartComponentRegistration,
      join_through: Oli.PartComponents.PartComponentRegistrationProject

    many_to_many :communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityVisibility

    has_many :publications, Oli.Publishing.Publication

    field :owner_id, :integer, virtual: true
    field :owner_name, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs \\ %{}) do
    project
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :version,
      :family_id,
      :project_id,
      :visibility,
      :status,
      :allow_duplication
    ])
    |> validate_required([:title, :version, :family_id])
    |> Slug.update_never("projects")
  end
end
