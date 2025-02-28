defmodule Oli.Analytics.Summary.ResourceSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_summary" do
    # These are the scope records (essentially to what scope do these summaries apply)

    field(:project_id, :integer, default: -1)
    field(:section_id, :integer, default: -1)
    field(:user_id, :integer, default: -1)

    belongs_to(:resource, Oli.Resources.Resource)
    field(:part_id, :string)

    belongs_to(:resource_type, Oli.Resources.ResourceType)

    field(:num_correct, :integer, default: 0)
    field(:num_attempts, :integer, default: 0)
    field(:num_hints, :integer, default: 0)
    field(:num_first_attempts, :integer, default: 0)
    field(:num_first_attempts_correct, :integer, default: 0)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [
      :project_id,
      :section_id,
      :user_id,
      :resource_id,
      :resource_type_id,
      :part_id,
      :num_correct,
      :num_attempts,
      :num_hints,
      :num_first_attempts,
      :num_first_attempts_correct
    ])
    |> validate_required([])
  end
end
