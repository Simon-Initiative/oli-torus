defmodule Oli.Delivery.Attempts.PartAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "part_attempts" do

    field :attempt_number, :integer
    field :date_evaluated, :utc_datetime
    field :score, :decimal
    field :out_of, :decimal
    field :response, :map
    field :feedback, :map
    field :hints, {:array, :string}, default: []
    field :part_id, :string

    belongs_to :resource_attempt, Oli.Delivery.Attempts.ResourceAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:attempt_number, :date_evaluated, :score, :out_of, :response, :feedback, :hints, :part_id, :resource_attempt_id])
    |> validate_required([:attempt_number, :part_id, :resource_attempt_id])
  end
end
