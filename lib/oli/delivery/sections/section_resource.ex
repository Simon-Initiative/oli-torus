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

    # an array of ids to other section resources
    field :children, {:array, :id}, default: []

    # the resource slug, resource and project mapping
    field :slug, :string
    field :resource_id, :integer
    belongs_to :project, Project

    # the section this section resource belongs to
    belongs_to :section, Section

    # resource delivery policy
    belongs_to :delivery_policy, DeliveryPolicy

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_resource, attrs) do
    section_resource
    |> cast(attrs, [
      :numbering_index,
      :numbering_level,
      :children,
      :slug,
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
      :children,
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
