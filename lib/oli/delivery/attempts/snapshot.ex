defmodule Oli.Delivery.Attempts.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset

  # A summary of part attempt history designed to power analytic queries

  schema "snapshots" do

    # The page, activity and part that this snapshot pertains to
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :activity, Oli.Resources.Resource
    field :part_id, :string

    # Which user and section
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section

    # At the time of the attempt which objectives and their revisions
    # that were attached to this part
    field :objectives, {:array, :id}
    field :objective_revisions, {:array, :id}

    # The exact revision of the activity at the time of this attempt
    belongs_to :revision, Oli.Resources.Revision

    # A reference to the type of the activity
    field :activity_type_id, :id

    # Attempt number, but to determine attempt counts one should probably aggregate record instances.
    # The attempt number is useful to power a query like:
    # "What percentage of first attempts are correct?"
    field :attempt_number, :integer

    # Whether or not this attempt was correct (true) or error (false)
    field :correct, :boolean

    # The raw score and out of points
    field :score, :decimal
    field :out_of, :decimal

    # Count of the number of hints received during this attempt
    field :hints, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(problem_step_rollup, attrs) do
    problem_step_rollup
    |> cast(attrs, [:resource_id, :activity_id, :part_id, :user_id, :section_id,
      :score, :out_of,
      :objectives, :objective_revisions, :revision_id, :activity_type_id, :attempt_number, :correct, :hints])
    |> validate_required([:resource_id, :activity_id, :part_id, :user_id, :section_id,
      :score, :out_of,
      :objectives, :objective_revisions, :revision_id, :activity_type_id, :attempt_number, :correct, :hints])
  end
end
