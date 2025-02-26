defmodule Oli.Analytics.Summary.ResponseSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "response_summary" do
    field(:project_id, :integer, default: -1)
    field(:section_id, :integer, default: -1)

    belongs_to(:page, Oli.Resources.Resource)
    belongs_to(:activity, Oli.Resources.Resource)
    belongs_to(:resource_part_response, Oli.Analytics.Summary.ResourcePartResponse)
    field(:part_id, :string)

    field(:count, :integer, default: 0)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [
      :project_id,
      :section_id,
      :page_id,
      :activity_id,
      :resource_part_response_id,
      :part_id,
      :count
    ])
    |> validate_required([])
  end
end
