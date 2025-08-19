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

  @required_fields [
    :type,
    :title,
    :registration_open,
    :base_project_id
  ]

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
    field(:analytics_version, Ecto.Enum, values: [:v1, :v2], default: :v2)

    field(:status, Ecto.Enum, values: [:active, :deleted, :archived], default: :active)
    field(:invite_token, :string)
    field(:passcode, :string)
    field(:cover_image, :string)

    field(:visibility, Ecto.Enum, values: [:selected, :global], default: :global)
    field(:requires_payment, :boolean, default: false)

    field(:payment_options, Ecto.Enum,
      values: [:direct, :deferred, :direct_and_deferred],
      default: :direct_and_deferred
    )

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

    field(:resource_gating_index, :map, default: %{})
    field(:previous_next_index, :map, default: nil)
    field(:display_curriculum_item_numbering, :boolean, default: true)
    field(:contains_discussions, :boolean, default: false)
    field(:contains_explorations, :boolean, default: false)
    field(:contains_deliberate_practice, :boolean, default: false)

    field(:certificate_enabled, :boolean, default: false)
    has_one(:certificate, Oli.Delivery.Sections.Certificate, on_replace: :delete)

    belongs_to(:required_survey, Oli.Resources.Resource,
      foreign_key: :required_survey_resource_id
    )

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
    field(:creator, :string, virtual: true)
    field(:instructors, {:array, {:array, :string}}, virtual: true)

    many_to_many(:communities, Oli.Groups.Community, join_through: Oli.Groups.CommunityVisibility)

    belongs_to(:publisher, Oli.Inventories.Publisher)

    # fields for course creation
    field(:class_modality, Ecto.Enum,
      values: [:never, :online, :in_person, :hybrid],
      default: :never
    )

    field(:class_days, {:array, Ecto.Enum},
      values: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday],
      default: []
    )

    field(:course_section_number, :string)

    field(:preferred_scheduling_time, :time, default: ~T[23:59:59])

    field(:v25_migration, Ecto.Enum,
      values: [:not_started, :done, :pending],
      default: :done
    )

    field(:page_prompt_template, :string)

    # we store the full section hierarchy to avoid having to build it on the fly when needed.

    # Allow major project publications to be applied to course sections created from this product
    field(:apply_major_updates, :boolean, default: false)

    # enable/disable the ai chatbot assistant for this section
    field(:assistant_enabled, :boolean, default: false)
    field(:triggers_enabled, :boolean, default: false)

    field(:welcome_title, :map, default: %{})

    field(:encouraging_subtitle, :string)

    field(:agenda, :boolean, default: true)
    field(:progress_scoring_settings, :map, default: %{"enabled" => false})

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
      :analytics_version,
      :status,
      :invite_token,
      :passcode,
      :cover_image,
      :visibility,
      :requires_payment,
      :payment_options,
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
      :contains_discussions,
      :contains_explorations,
      :contains_deliberate_practice,
      :required_survey_resource_id,
      :class_modality,
      :class_days,
      :course_section_number,
      :preferred_scheduling_time,
      :v25_migration,
      :page_prompt_template,
      :apply_major_updates,
      :assistant_enabled,
      :triggers_enabled,
      :welcome_title,
      :encouraging_subtitle,
      :agenda,
      :certificate_enabled,
      :progress_scoring_settings
    ])
    |> cast_embed(:customizations, required: false)
    |> validate_required(@required_fields)
    |> validate_required_if([:amount], &requires_payment?/1)
    |> validate_required_if([:grace_period_days], &has_grace_period?/1)
    |> validate_required_if([:publisher_id, :apply_major_updates], &is_product?/1)
    |> foreign_key_constraint_if(:publisher_id, &is_product?/1)
    |> validate_positive_grace_period()
    |> validate_positive_money()
    |> enforce_minimum_price()
    |> validate_dates_consistency(:start_date, :end_date)
    |> unique_constraint(:context_id, name: :sections_active_context_id_unique_index)
    |> Slug.update_never("sections")
    |> validate_length(:title, max: 255)
    |> cast_assoc(:certificate)
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

  def validate_positive_money(changeset) do
    validate_change(changeset, :amount, fn _, amount ->
      if requires_payment?(changeset) do
        case Money.compare(Money.new(1, "USD"), amount) do
          :gt -> [{:amount, "must be greater than or equal to one"}]
          _ -> []
        end
      else
        []
      end
    end)
  end

  def enforce_minimum_price(changeset) do
    if !is_nil(get_field(changeset, :amount)) do
      case Money.compare(get_field(changeset, :amount), Money.new(1, "USD")) do
        :lt -> put_change(changeset, :amount, Money.new(1, "USD"))
        _ -> changeset
      end
    else
      changeset
    end
  end

  @doc """
  Returns the required fields for a section.
  """
  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  defp requires_payment?(changeset), do: get_field(changeset, :requires_payment)

  defp has_grace_period?(changeset),
    do: get_field(changeset, :has_grace_period) and get_field(changeset, :requires_payment)

  defp is_product?(changeset), do: get_field(changeset, :type) == :blueprint
end
