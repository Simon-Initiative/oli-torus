defmodule Oli.Delivery.Learning.Data.ProblemStepRollup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "problem_step_rollup" do
    field :attempts, :integer
    field :correct, :integer
    field :date_correct, :utc_datetime
    field :errors, :integer
    field :first_attempt_correct, :boolean, default: false
    field :hints, :integer
    field :opportunity, :integer
    field :problem_id, :string
    field :resource_slug, :string
    field :section_slug, :string
    field :step_id, :string
    field :user_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(problem_step_rollup, attrs) do
    problem_step_rollup
    |> cast(attrs, [:section_slug, :user_id, :resource_slug, :problem_id, :step_id, :opportunity, :hints, :errors, :attempts, :correct, :first_attempt_correct, :date_correct])
    |> validate_required([:section_slug, :user_id, :resource_slug, :problem_id, :step_id, :opportunity, :hints, :errors, :attempts, :correct])
  end
end
