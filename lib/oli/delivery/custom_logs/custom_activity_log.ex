defmodule Oli.Delivery.CustomLogs.CustomActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  # Activity attempt logs designed to power analytic queries

  schema "custom_activity_logs" do

    belongs_to(:resource, Oli.Resources.Resource)

    # Which user and section
    belongs_to(:user, Oli.Accounts.User)
    belongs_to(:section, Oli.Delivery.Sections.Section)

    belongs_to(:activity_attempt, Oli.Delivery.Attempts.Core.ActivityAttempt)
    belongs_to(:revision, Oli.Resources.Revision)

    # Type of the activity
    field(:activity_type, :string)

    field(:attempt_number, :integer)

    field(:action, :string)
    field(:info, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(problem_step_rollup, attrs) do
    problem_step_rollup
    |> cast(attrs, [
      :resource_id,
      :user_id,
      :section_id,
      :activity_attempt_id,
      :revision_id,
      :activity_type,
      :attempt_number,
      :action,
      :info,

    ])
    |> validate_required([
      :resource_id,
      :user_id,
      :section_id,
      :activity_attempt_id,
      :revision_id,
      :activity_type,
      :attempt_number,
      :action,
      :info,
    ])
  end
end
