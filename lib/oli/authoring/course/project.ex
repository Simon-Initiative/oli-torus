defmodule Oli.Authoring.Course.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Authoring.Course.ProjectAttributes
  alias Oli.Branding.CustomLabels
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
    field :has_experiments, :boolean, default: false
    field :legacy_svn_root, :string

    embeds_one :customizations, CustomLabels, on_replace: :delete
    embeds_one :attributes, ProjectAttributes, on_replace: :delete

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

    has_many :publications, Oli.Publishing.Publications.Publication

    belongs_to :publisher, Oli.Inventories.Publisher

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
      :allow_duplication,
      :has_experiments,
      :legacy_svn_root,
      :publisher_id
    ])
    |> cast_embed(:attributes, required: false)
    |> cast_embed(:customizations, required: false)
    |> validate_required([:title, :version, :family_id, :publisher_id])
    |> foreign_key_constraint(:publisher_id)
    |> Slug.update_never("projects")
  end

  def new_project_changeset(project, attrs \\ %{}) do
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
      :allow_duplication,
      :has_experiments,
      :legacy_svn_root,
      :publisher_id
    ])
    |> validate_required([:title, :version, :family_id, :publisher_id])
    |> foreign_key_constraint(:publisher_id)
    |> Slug.update_never("projects")
  end
end
