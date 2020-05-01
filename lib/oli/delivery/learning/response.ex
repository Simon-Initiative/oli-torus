defmodule Oli.Delivery.Learning.Response do
  use Ecto.Schema
  import Ecto.Changeset

  schema "responses" do
    field :current, :boolean, default: false
    # This represents blob of content from a user input wrapped in json
    field :input_value, :map

    belongs_to :interaction, Oli.Delivery.Learning.Interaction
    belongs_to :problem_attempt, Oli.Delivery.Learning.ProblemAttempt
    has_many :feedbacks, Oli.Delivery.Learning.Feedback

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:interaction_id, :problem_attempt_id, :input_value, :current])
    |> validate_required([:interaction_id, :problem_attempt_id, :input_value, :current])
  end
end
