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
    field :type, Ecto.Enum, values: [:enrollable, :blueprint], default: :enrollable

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

    field :visibility, Ecto.Enum, values: [:selected, :global], default: :global
    field :requires_payment, :boolean, default: false
    field :amount, Money.Ecto.Map.Type
    field :has_grace_period, :boolean, default: true
    field :grace_period_days, :integer

    field :grace_period_strategy, Ecto.Enum,
      values: [:relative_to_section, :relative_to_student],
      default: :relative_to_section

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

    belongs_to :blueprint, Oli.Delivery.Sections.Section

    # ternary association for sections, projects, and publications used for pinning
    # specific projects and publications to a section for resource resolution
    has_many :section_project_publications, SectionsProjectsPublications, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs \\ %{}) do
    section
    |> cast(attrs, [
      :type,
      :title,
      :start_date,
      :end_date,
      :timezone,
      :registration_open,
      :description,
      :context_id,
      :slug,
      :open_and_free,
      :status,
      :invite_token,
      :passcode,
      :visibility,
      :requires_payment,
      :amount,
      :has_grace_period,
      :grace_period_days,
      :grace_period_strategy,
      :grade_passback_enabled,
      :line_items_service_url,
      :nrps_enabled,
      :nrps_context_memberships_url,
      :lti_1p3_deployment_id,
      :institution_id,
      :base_project_id,
      :brand_id,
      :delivery_policy_id,
      :blueprint_id,
      :root_section_resource_id
    ])
    |> validate_required([
      :type,
      :title,
      :timezone,
      :registration_open,
      :base_project_id
    ])
    |> validate_positive_grace_period()
    |> validate_positive_amount()
    |> Slug.update_never("sections")
  end

  def validate_positive_grace_period(changeset) do
    validate_change(changeset, :grace_period_days, fn _, days ->
      case days >= 0 do
        true -> []
        false -> [{:grace_period_days, "must be greater than or equal to zero"}]
      end
    end)
  end

  def validate_positive_amount(changeset) do
    validate_change(changeset, :amount, fn _, amount ->
      case Money.compare(Money.new(:USD, 0), amount) do
        :gt -> [{:amount, "must be greater than or equal to zero"}]
        _ -> []
      end
    end)
  end
end
