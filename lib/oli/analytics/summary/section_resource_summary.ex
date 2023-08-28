defmodule Oli.Analytics.Summary.SectionResourceSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_resource_summary" do

    belongs_to(:section, Oli.Delivery.Sections.Section)
    belongs_to(:user, Oli.Accounts.User)

    belongs_to(:resource, Oli.Resources.Resource)
    belongs_to(:resource_type, Oli.Resources.ResourceType)
    field(:part_id, :string)

    field(:num_correct, :integer, default: 0)
    field(:num_attempts, :integer, default: 0)
    field(:num_hints, :integer, default: 0)
    field(:num_first_attempts, :integer, default: 0)
    field(:num_first_attempts_correct, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:section_id, :user_id, :resource_id, :resource_type_id, :part_id, :num_correct, :num_attempts, :num_hints, :num_first_attempts, :num_first_attempts_correct])
    |> validate_required([:section_id, :resource_id, :resource_type_id])
  end

end
