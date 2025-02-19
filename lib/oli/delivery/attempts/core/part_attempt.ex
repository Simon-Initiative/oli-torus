defmodule Oli.Delivery.Attempts.Core.PartAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "part_attempts" do
    field(:attempt_guid, :string)
    field(:attempt_number, :integer)
    field(:grading_approach, Ecto.Enum, values: [:automatic, :manual], default: :automatic)

    field(:lifecycle_state, Ecto.Enum,
      values: [:active, :submitted, :evaluated],
      default: :active
    )

    field(:date_evaluated, :utc_datetime)
    field(:date_submitted, :utc_datetime)
    field(:score, :float)
    field(:out_of, :float)
    field(:response, :map)
    field(:feedback, :map)
    field(:hints, {:array, :string}, default: [])
    field(:part_id, :string)
    field(:datashop_session_id, :string)

    belongs_to(:activity_attempt, Oli.Delivery.Attempts.Core.ActivityAttempt)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :attempt_guid,
      :attempt_number,
      :grading_approach,
      :lifecycle_state,
      :date_evaluated,
      :date_submitted,
      :score,
      :out_of,
      :response,
      :feedback,
      :hints,
      :part_id,
      :datashop_session_id,
      :activity_attempt_id
    ])
    |> validate_required([
      :attempt_guid,
      :attempt_number,
      :part_id,
      :activity_attempt_id
    ])
  end
end
