defmodule Oli.Delivery.Attempts.Core.ResourceAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_attempts" do
    field(:attempt_guid, :string)
    field(:attempt_number, :integer)

    field(:lifecycle_state, Ecto.Enum, values: [:active, :submitted, :evaluated], default: :active)

    field(:date_evaluated, :utc_datetime)
    field(:date_submitted, :utc_datetime)
    field(:score, :float)
    field(:out_of, :float)
    field(:state, :map, default: %{})
    field(:content, :map)
    field(:errors, {:array, :string}, default: [])

    belongs_to(:resource_access, Oli.Delivery.Attempts.Core.ResourceAccess)
    belongs_to(:revision, Oli.Resources.Revision)
    has_many(:activity_attempts, Oli.Delivery.Attempts.Core.ActivityAttempt)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :attempt_guid,
      :attempt_number,
      :score,
      :out_of,
      :lifecycle_state,
      :content,
      :errors,
      :state,
      :date_evaluated,
      :date_submitted,
      :resource_access_id,
      :revision_id
    ])
    |> validate_required([
      :attempt_guid,
      :attempt_number,
      :resource_access_id,
      :revision_id,
      :content
    ])
  end
end
