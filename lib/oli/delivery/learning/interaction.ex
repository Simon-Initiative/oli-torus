defmodule Oli.Delivery.Learning.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "interactions" do
    field :interaction_guid, :string
    field :name, :string

    belongs_to :problem_attempt, Oli.Delivery.Learning.ProblemAttempt
    # This one-to-many relation tracks multiple answers at the same input before an official submit is issued by the learner
    # Example would be in a quiz where learner enters a value in an input field, we autosave that, later during the quiz
    # learner changes their mind and enters a new value in the same input field, we autosave that the new "current" response
    # In most use cases, one response prevalent
    has_many :responses, Oli.Delivery.Learning.Response

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:problem_attempt_id, :interaction_guid, :name])
    |> validate_required([:problem_attempt_id, :interaction_guid, :name])
  end
end
