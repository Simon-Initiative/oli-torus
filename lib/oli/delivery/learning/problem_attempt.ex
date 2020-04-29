defmodule Oli.Delivery.Learning.ProblemAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "problem_attempts" do
    field :attempt_number, :integer
    field :children, {:array, :id}, default: []
    field :correct, :boolean, default: false
    field :date_evaluated, :utc_datetime
    field :feedback_visible, :boolean, default: false
    field :hint, :map
    field :hint_visible, :boolean, default: false
    field :problem_id, :string

    belongs_to :activity_attempt, Oli.Delivery.Learning.ActivityAttempt
    belongs_to :parent, Oli.Delivery.Learning.ProblemAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(problem_attempt, attrs) do
    problem_attempt
    |> cast(attrs, [:activity_attempt_id, :parent_id, :attempt_number, :problem_id, :correct, :date_evaluated, :children, :feedback_visible, :hint_visible, :hint])
    |> validate_required([:attempt_number, :problem_id])
  end
end
