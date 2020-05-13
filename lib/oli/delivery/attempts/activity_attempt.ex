defmodule Oli.Delivery.Attempts.ActivityAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_attempts" do

    field :attempt_guid, :string
    field :attempt_number, :integer
    field :date_evaluated, :utc_datetime
    field :score, :float
    field :out_of, :float
    field :transformed_model, :map

    belongs_to :resource, Oli.Resources.Resource
    belongs_to :revision, Oli.Resources.Revision
    belongs_to :resource_attempt, Oli.Delivery.Attempts.ResourceAttempt
    has_many :part_attempts, Oli.Delivery.Attempts.PartAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:attempt_guid, :attempt_number, :score, :out_of, :date_evaluated, :transformed_model, :resource_attempt_id, :resource_id, :revision_id])
    |> validate_required([:attempt_guid, :attempt_number, :transformed_model, :resource_attempt_id, :resource_id, :revision_id])
  end
end
