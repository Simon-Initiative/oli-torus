defmodule Oli.Delivery.Attempts.ResourceAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_attempts" do
    field :attempt_guid, :string
    field :attempt_number, :integer
    field :date_evaluated, :utc_datetime
    field :score, :float
    field :out_of, :float

    belongs_to :resource_access, Oli.Delivery.Attempts.ResourceAccess
    belongs_to :revision, Oli.Resources.Revision
    has_many :activity_attempts, Oli.Delivery.Attempts.ActivityAttempt

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
      :date_evaluated,
      :resource_access_id,
      :revision_id
    ])
    |> validate_required([:attempt_guid, :attempt_number, :resource_access_id, :revision_id])
  end
end
