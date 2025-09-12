defmodule Oli.Delivery.BlacklistedActivity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section

  schema "blacklisted_activities" do
    belongs_to :section, Section
    field :activity_id, :integer
    field :selection_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(blacklisted_activity, attrs) do
    blacklisted_activity
    |> cast(attrs, [:section_id, :activity_id, :selection_id])
    |> validate_required([:section_id, :activity_id, :selection_id])
    |> unique_constraint([:section_id, :activity_id, :selection_id])
  end
end
