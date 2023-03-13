defmodule Oli.Delivery.Sections.Section do
  use Ecto.Schema
  import Ecto.Changeset

  import Oli.Utils
  alias Oli.Utils.Slug
  alias Oli.Authoring.Course.Project
  alias Oli.Institutions.Institution
  alias Oli.Branding.Brand
  alias Oli.Delivery.DeliveryPolicy
  alias Oli.Branding.CustomLabels

  alias Oli.Delivery.Sections.{
    SectionsProjectsPublications,
    Enrollment,
    SectionResource,
    SectionInvite,
    Section
  }

  schema "sections" do
    field(:type, Ecto.Enum, values: [:enrollable, :blueprint], default: :enrollable)

    field(:registration_open, :boolean, default: false)
    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)
    field(:title, :string)
    field(:description, :string)
    field(:context_id, :string)
    field(:slug, :string)
    field(:open_and_free, :boolean, default: false)
    field(:requires_enrollment, :boolean, default: false)
    field(:has_experiments, :boolean, default: false)

    field(:status, Ecto.Enum, values: [:active, :deleted, :archived], default: :active)
    field(:invite_token, :string)
    field(:passcode, :string)
    field(:cover_image, :string)

    field(:visibility, Ecto.Enum, values: [:selected, :global], default: :global)
    field(:requires_payment, :boolean, default: false)
    field(:pay_by_institution, :boolean, default: false)
    field(:amount, Money.Ecto.Map.Type)
    field(:has_grace_period, :boolean, default: true)
    field(:grace_period_days, :integer)

    field(:grace_period_strategy, Ecto.Enum,
      values: [:relative_to_section, :relative_to_student],
      default: :relative_to_section
    )

    field(:grade_passback_enabled, :boolean, default: false)
    field(:line_items_service_url, :string)
    field(:nrps_enabled, :boolean, default: false)
    field(:nrps_context_memberships_url, :string)

    field(:resource_gating_index, :map, default: %{}, null: false)
    field(:previous_next_index, :map, default: nil, null: true)
    field(:display_curriculum_item_numbering, :boolean, default: true)
    field(:contains_explorations, :boolean, default: false)

    embeds_one(:customizations, CustomLabels, on_replace: :delete)

    belongs_to(:lti_1p3_deployment, Oli.Lti.Tool.Deployment, foreign_key: :lti_1p3_deployment_id)

    belongs_to(:institution, Institution)
    belongs_to(:brand, Brand)

    has_many(:enrollments, Enrollment)

    # base project
    belongs_to(:base_project, Project)

    # root section resource container
    belongs_to(:root_section_resource, SectionResource)

    # section resources
    has_many(:section_resources, SectionResource)

    # section delivery policy
    belongs_to(:delivery_policy, DeliveryPolicy)

    belongs_to(:blueprint, Section)

    # ternary association for sections, projects, and publications used for pinning
    # specific projects and publications to a section for resource resolution
    has_many(:section_project_publications, SectionsProjectsPublications, on_replace: :delete)

    # Section Invites are used for "Direct Delivery" sections (open and free and require enrollment)
    # An instructor can create a "section invite" link with a hash that allows direct student
    # enrollment.
    has_many(:section_invites, SectionInvite, on_delete: :delete_all)
    # Boolean to indicate the student will be confirmed at creation moment and will not
    # receive a confirmation email.
    field(:skip_email_verification, :boolean, default: false)

    field(:enrollments_count, :integer, virtual: true)
    field(:total_count, :integer, virtual: true)
    field(:institution_name, :string, virtual: true)
    field(:instructor_name, :string, virtual: true)

    many_to_many(:communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityVisibility)

    belongs_to(:publisher, Oli.Inventories.Publisher)

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
      :registration_open,
      :description,
      :context_id,
      :slug,
      :open_and_free,
      :has_experiments,
      :status,
      :invite_token,
      :passcode,
      :cover_image,
      :visibility,
      :requires_payment,
      :pay_by_institution,
      :amount,
      :has_grace_period,
      :grace_period_days,
      :grace_period_strategy,
      :grade_passback_enabled,
      :line_items_service_url,
      :nrps_enabled,
      :nrps_context_memberships_url,
      :resource_gating_index,
      :previous_next_index,
      :lti_1p3_deployment_id,
      :institution_id,
      :base_project_id,
      :brand_id,
      :delivery_policy_id,
      :blueprint_id,
      :root_section_resource_id,
      :requires_enrollment,
      :skip_email_verification,
      :publisher_id,
      :display_curriculum_item_numbering,
      :contains_explorations
    ])
    |> cast_embed(:customizations, required: false)
    |> validate_required([
      :type,
      :title,
      :registration_open,
      :base_project_id
    ])
    |> validate_required_if([:amount], &requires_payment?/1)
    |> validate_required_if([:grace_period_days], &has_grace_period?/1)
    |> validate_required_if([:publisher_id], &is_product?/1)
    |> foreign_key_constraint_if(:publisher_id, &is_product?/1)
    |> validate_positive_grace_period()
    |> Oli.Delivery.Utils.validate_positive_money(:amount)
    |> validate_dates_consistency(:start_date, :end_date)
    |> unique_constraint(:context_id, name: :sections_active_context_id_unique_index)
    |> Slug.update_never("sections")
    |> validate_length(:title, max: 255)
  end

  def validate_positive_grace_period(changeset) do
    validate_change(changeset, :grace_period_days, fn _, days ->
      if get_field(changeset, :has_grace_period) and get_field(changeset, :requires_payment) do
        case days >= 1 do
          true -> []
          false -> [{:grace_period_days, "must be greater than or equal to one"}]
        end
      else
        []
      end
    end)
  end

  defp requires_payment?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :requires_payment)

      _ ->
        false
    end
  end

  defp has_grace_period?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :has_grace_period) and get_field(changeset, :requires_payment)

      _ ->
        false
    end
  end

  defp is_product?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :type) == :blueprint

      _ ->
        false
    end
  end
end
