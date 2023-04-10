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
    field(:scheduling_type, Ecto.Enum, values: [:read_by, :inclass_activity], default: :read_by)
    field(:manually_scheduled, :boolean)
    field(:start_date, :date)
    field(:end_date, :date)

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
      :resource_id,
      :project_id,
      :section_id,
      :delivery_policy_id
    ])
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
