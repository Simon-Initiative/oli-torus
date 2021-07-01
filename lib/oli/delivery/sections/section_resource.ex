defmodule Oli.Delivery.Sections.SectionResource do
  use Ecto.Schema
  import Ecto.Changeset

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
  def changeset(section, attrs) do
    section
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
      :numbering_index,
      :numbering_level,
      :children,
      :slug,
      :resource_id,
      :project_id,
      :section_id
    ])
  end
end
