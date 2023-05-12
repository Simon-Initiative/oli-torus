defmodule Oli.Delivery.Sections.SectionResource do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.DeliveryPolicy

  # contextual information
  schema "section_resources" do
    # the index of this resource within the flattened ordered list of section resources
    field :numbering_index, :integer
    field :numbering_level, :integer

    # soft scheduling
    field(:scheduling_type, Ecto.Enum, values: [:due_by, :read_by, :inclass_activity], default: :read_by)
    field(:manually_scheduled, :boolean)
    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)

    # instructor overridable page settings
    embeds_one :collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig, on_replace: :delete
    embeds_one :explanation_strategy, Oli.Resources.ExplanationStrategy, on_replace: :delete

    # assessment settings
    field :max_attempts, :integer, default: 0
    field :retake_mode, Ecto.Enum, values: [:normal, :targeted], default: :normal
    field :late_submit, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :late_start, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :time_limit, :integer, default: 0
    field :grace_period, :integer, default: 0
    belongs_to :scoring_strategy, Oli.Resources.ScoringStrategy
    field :review_submission, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :feedback_mode, Ecto.Enum, values: [:allow, :disallow, :scheduled], default: :allow
    field :feedback_scheduled_date, :utc_datetime

    # an array of ids to other section resources
    field :children, {:array, :id}, default: []

    # if a container, records the total number of contained pages
    field :contained_page_count, :integer, default: 0

    # the resource slug, resource and project mapping
    field :slug, :string
    field :resource_id, :integer
    belongs_to :project, Project

    # the section this section resource belongs to
    belongs_to :section, Section

    # resource delivery policy
    belongs_to :delivery_policy, DeliveryPolicy

    field(:title, :string, virtual: true)
    field(:graded, :boolean, virtual: true)
    field(:resource_type_id, :integer, virtual: true)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_resource, attrs) do
    section_resource
    |> cast(attrs, [
      :numbering_index,
      :numbering_level,
      :children,
      :contained_page_count,
      :slug,
      :scheduling_type,
      :start_date,
      :end_date,
      :manually_scheduled,
      :max_attempts,
      :retake_mode,
      :late_submit,
      :late_start,
      :time_limit,
      :grace_period,
      :review_submission,
      :feedback_mode,
      :feedback_scheduled_date,
      :scoring_strategy_id,
      :resource_id,
      :project_id,
      :section_id,
      :delivery_policy_id
    ])
    |> cast_embed(:explanation_strategy)
    |> cast_embed(:collab_space_config)
    |> validate_required([
      :slug,
      :resource_id,
      :project_id,
      :section_id
    ])
    |> unique_constraint([:section_id, :resource_id])
  end

  def to_map(%SectionResource{} = section_resource) do
    section_resource
    |> Map.from_struct()
    |> Map.take([
      :id,
      :numbering_index,
      :numbering_level,
      :scheduling_type,
      :start_date,
      :end_date,
      :children,
      :contained_page_count,
      :slug,
      :resource_id,
      :project_id,
      :section_id,
      :delivery_policy_id,
      :inserted_at,
      :updated_at
    ])
  end
end
