defmodule Oli.Delivery.Learning.Score do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scores" do
    field :assigned_by, :string
    field :date_overridden, :utc_datetime
    field :date_scored, :utc_datetime
    field :out_of, :decimal
    field :overridden_by, :string
    field :override, :decimal
    field :points, :decimal
    field :score, :decimal
    field :score_explanation, :string

    belongs_to :activity_access, Oli.Delivery.Learning.ActivityAccess
    belongs_to :activity_attempt, Oli.Delivery.Learning.ActivityAttempt
    belongs_to :problem_attempt, Oli.Delivery.Learning.ProblemAttempt
    belongs_to :response, Oli.Delivery.Learning.Response

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:activity_access_id, :activity_attempt_id, :problem_attempt_id, :score, :points, :out_of, :date_scored, :assigned_by, :score_explanation, :override, :overridden_by, :date_overridden])
    |> validate_required([:score, :points, :date_scored])
  end
end
