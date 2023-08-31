defmodule Oli.Analytics.Summary.SectionResponseSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "response_summary" do

    belongs_to(:section, Oli.Delivery.Sections.Section)
    belongs_to(:page, Oli.Resources.Resource)
    belongs_to(:activity, Oli.Resources.Resource)
    field(:part_id, :string)

    field(:label, :string)
    field(:count, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:section_id, :page_id, :activity_id, :part_id, :label, :count])
    |> validate_required([:section_id, :page_id, :activity_id, :part_id, :label, :count])
  end

end
