defmodule Oli.Delivery.Learning.ActivityAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_attempts" do
    field :accepted, :boolean, default: false
    field :attempt_number, :integer
    field :date_completed, :utc_datetime
    field :date_processed, :utc_datetime
    field :date_submitted, :utc_datetime
    field :deadline, :utc_datetime
    field :last_accessed, :utc_datetime
    field :late_submission, :boolean, default: false
    field :processed_by, :string

    belongs_to :revision, Oli.Resources.Revision
    belongs_to :activity_access, Oli.Delivery.Learning.ActivityAccess
    has_one :score, Oli.Delivery.Learning.Score
    has_many :problems, Oli.Delivery.Learning.ProblemAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity_attempt, attrs) do
    activity_attempt
    |> cast(attrs, [:revision_id, :activity_access_id, :attempt_number, :deadline, :last_accessed, :date_completed, :date_submitted, :late_submission, :accepted, :processed_by, :date_processed])
    |> validate_required([:activity_access_id, :attempt_number, :last_accessed])
  end
end
