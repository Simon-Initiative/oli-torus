defmodule Oli.Delivery.Sections.SectionResourceSummary do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Resources.Resource
  alias Oli.Delivery.Sections.Section

  schema "section_resource_summary" do

    belongs_to :section, Section
    belongs_to :resource, Resource
    belongs_to :resource_type, Oli.Resources.ResourceType
    belongs_to :activity_type, Oli.Activities.ActivityRegistration

    field(:title, :string)
    field(:graded, :boolean)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_resource, attrs \\ %{}) do
    section_resource
    |> cast(attrs, [
      :section_id,
      :resource_id,
      :title,
      :graded,
      :resource_type_id,
      :activity_type_id
    ])
    |> validate_required([
      :section_id,
      :resource_id,
      :title,
      :graded,
      :resource_type_id
    ])
  end

end
