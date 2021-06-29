defmodule Oli.Delivery.Sections.SectionResource do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.DeliveryPolicy

  # contextual information
  schema "section_resources" do
    # the index of this resource within the flattened ordered list of section resources
    field :numbering_index, :integer
    field :container_type, Ecto.Enum, values: [:unit, :module]

    # an array of ids to other section resources
    field :children, {:array, :id}, default: []

    # the resource slug, resource and project mapping
    field :slug, :string
    field :resource_id, :string
    belongs_to :project, Project

    # the section this section resource belongs to
    belongs_to :section, Section

    # the delivery policy, if one exists, for this resource
    belongs_to :section_policy, DeliveryPolicy
    has_many :policies, DeliveryPolicy

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :numbering_index,
      :container_type,
      :children,
      :slug,
      :resource_id,
      :project,
      :section,
      :policy
    ])
    |> validate_required([
      :numbering_index,
      :container_type,
      :children,
      :slug,
      :resource_id,
      :project,
      :section,
      :policy
    ])
  end
end
