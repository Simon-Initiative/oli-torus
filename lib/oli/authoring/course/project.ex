defmodule Oli.Authoring.Course.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Authoring.Course.ProjectAttributes
  alias Oli.Branding.CustomLabels
  alias Oli.Utils.Slug

  @derive {Phoenix.Param, key: :slug}
  schema "projects" do
    field(:description, :string)
    field(:slug, :string)
    field(:title, :string)
    field(:version, :string)
    field(:visibility, Ecto.Enum, values: [:authors, :selected, :global], default: :authors)
    field(:status, Ecto.Enum, values: [:active, :deleted], default: :active)
    field(:allow_duplication, :boolean, default: false)
    field(:has_experiments, :boolean, default: false)
    field(:legacy_svn_root, :string)
    field(:allow_ecl_content_type, :boolean, default: false)
    field(:allow_triggers, :boolean, default: false)
    field(:latest_export_url, :string)
    field(:latest_export_timestamp, :utc_datetime)
    field(:latest_analytics_snapshot_url, :string)
    field(:latest_analytics_snapshot_timestamp, :utc_datetime)
    field(:latest_datashop_snapshot_url, :string)
    field(:latest_datashop_snapshot_timestamp, :utc_datetime)
    field(:analytics_version, Ecto.Enum, values: [:v1, :v2], default: :v2)
    field(:allow_transfer_payment_codes, :boolean, default: false)
    field(:welcome_title, :map, default: %{})

    field(:encouraging_subtitle, :string)
    field(:auto_update_sections, :boolean, default: true)

    embeds_one(:customizations, CustomLabels, on_replace: :delete)
    embeds_one(:attributes, ProjectAttributes, on_replace: :delete)

    belongs_to(:parent_project, Oli.Authoring.Course.Project, foreign_key: :project_id)
    belongs_to(:family, Oli.Authoring.Course.Family)
    many_to_many(:authors, Oli.Accounts.Author, join_through: Oli.Authoring.Authors.AuthorProject)

    many_to_many(:resources, Oli.Resources.Resource,
      join_through: Oli.Authoring.Course.ProjectResource
    )

    many_to_many(:activity_registrations, Oli.Activities.ActivityRegistration,
      join_through: Oli.Activities.ActivityRegistrationProject
    )

    many_to_many(:part_component_registrations, Oli.PartComponents.PartComponentRegistration,
      join_through: Oli.PartComponents.PartComponentRegistrationProject
    )

    many_to_many(:communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityVisibility)
    many_to_many(:tags, Oli.Tags.Tag, join_through: Oli.Tags.ProjectTag)

    has_many(:publications, Oli.Publishing.Publications.Publication)

    belongs_to(:publisher, Oli.Inventories.Publisher)

    field(:owner_id, :integer, virtual: true)
    field(:owner_name, :string, virtual: true)

    belongs_to(:required_survey, Oli.Resources.Resource,
      foreign_key: :required_survey_resource_id
    )

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
      :allow_ecl_content_type,
      :allow_triggers,
      :analytics_version,
      :publisher_id,
      :required_survey_resource_id,
      :latest_export_url,
      :latest_export_timestamp,
      :latest_analytics_snapshot_url,
      :latest_analytics_snapshot_timestamp,
      :latest_datashop_snapshot_url,
      :latest_datashop_snapshot_timestamp,
      :allow_transfer_payment_codes,
      :welcome_title,
      :encouraging_subtitle,
      :auto_update_sections
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
      :allow_ecl_content_type,
      :allow_triggers,
      :publisher_id,
      :auto_update_sections
    ])
    |> validate_required([:title, :version, :family_id, :publisher_id])
    |> foreign_key_constraint(:publisher_id)
    |> Slug.update_never("projects")
  end
end
