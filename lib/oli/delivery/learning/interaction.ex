defmodule Oli.Delivery.Learning.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "interactions" do
    field :interaction_guid, :string
    field :name, :string

    belongs_to :problem_attempt, Oli.Delivery.Learning.ProblemAttempt
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
