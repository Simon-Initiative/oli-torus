defmodule Oli.Analytics.Summary.ResourcePartResponse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_part_responses" do

    belongs_to(:resource_id, Oli.Resources.Resource)
    field(:part_id, :string)
    field(:response, :string)
    field(:label, :string)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:resource_id, :part_id, :response, :label])
    |> validate_required([:resource_id, :part_id, :response, :label])
  end

end
