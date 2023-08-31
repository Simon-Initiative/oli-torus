defmodule Oli.Analytics.Summary.ResponseSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "response_summary" do

    field(:project_id, :integer, default: -1)
    field(:publication_id, :integer, default: -1)
    field(:section_id, :integer, default: -1)

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
    |> cast(attrs, [:project_id, :publication_id, :section_id, :page_id, :activity_id, :part_id, :label, :count])
    |> validate_required([])
  end

end
