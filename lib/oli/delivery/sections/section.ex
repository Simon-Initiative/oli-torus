defmodule Oli.Delivery.Sections.Section do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Institutions.Institution
  alias Oli.Branding.Brand
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.DeliveryPolicy
  alias Oli.Delivery.Sections.SectionsProjectsPublications

  schema "sections" do
    field :registration_open, :boolean, default: false
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :timezone, :string
    field :title, :string
    field :description, :string
    field :context_id, :string
    field :slug, :string
    field :open_and_free, :boolean, default: false
    field :status, Ecto.Enum, values: [:active, :deleted], default: :active
    field :invite_token, :string
    field :passcode, :string

    field :grade_passback_enabled, :boolean, default: false
    field :line_items_service_url, :string
    field :nrps_enabled, :boolean, default: false
    field :nrps_context_memberships_url, :string

    belongs_to :lti_1p3_deployment, Lti_1p3.DataProviders.EctoProvider.Deployment,
      foreign_key: :lti_1p3_deployment_id

    belongs_to :institution, Institution
    belongs_to :brand, Brand

    has_many :enrollments, Enrollment

    # base project
    belongs_to :base_project, Project

    # root section resource container
    belongs_to :root_section_resource, SectionResource

    # section resources
    has_many :section_resources, SectionResource

    # section delivery policy
    belongs_to :delivery_policy, DeliveryPolicy

    # ternary association for sections, projects, and publications used for pinning
    # specific projects and publications to a section for resource resolution
    has_many :section_project_publications, SectionsProjectsPublications, on_replace: :delete

    # TODO: REMOVE
    # many_to_many :projects, Project, join_through: SectionsProjectsPublications

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs \\ %{}) do
    section
    |> cast(attrs, [
      :title,
      :start_date,
      :end_date,
      :timezone,
      :registration_open,
      :context_id,
      :slug,
      :open_and_free,
      :status,
      :invite_token,
      :passcode,
      :grade_passback_enabled,
      :line_items_service_url,
      :nrps_enabled,
      :nrps_context_memberships_url,
      :lti_1p3_deployment_id,
      :institution_id,
      :base_project_id,
      :brand_id,
      :delivery_policy_id,
      :root_section_resource_id
    ])
    |> validate_required([
      :title,
      :timezone,
      :registration_open,
      :base_project_id
    ])
    |> Slug.update_never("sections")
  end
end
