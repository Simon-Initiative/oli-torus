defmodule Oli.Delivery.Attempts.Core.ActivityAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_attempts" do
    field(:attempt_guid, :string)
    field(:attempt_number, :integer)

    field(:lifecycle_state, Ecto.Enum,
      values: [:active, :submitted, :evaluated],
      default: :active
    )

    field(:date_evaluated, :utc_datetime)
    field(:date_submitted, :utc_datetime)
    field(:scoreable, :boolean, default: true)
    field(:score, :float)
    field(:out_of, :float)
    field(:aggregate_score, :float, default: nil)
    field(:aggregate_out_of, :float, default: nil)
    field(:custom_scores, :map)
    field(:transformed_model, :map, default: nil)
    field(:group_id, :string, default: nil)
    field(:survey_id, :string, default: nil)
    field(:selection_id, :string, default: nil)
    field(:cleanup, :integer, default: -1)

    belongs_to(:resource, Oli.Resources.Resource)
    belongs_to(:revision, Oli.Resources.Revision)
    belongs_to(:resource_attempt, Oli.Delivery.Attempts.Core.ResourceAttempt)
    has_many(:part_attempts, Oli.Delivery.Attempts.Core.PartAttempt)

    field :resource_access_id, :integer, virtual: true
    field :resource_attempt_guid, :string, virtual: true
    field :resource_attempt_number, :integer, virtual: true
    field :page_id, :integer, virtual: true
    field :activity_type_id, :integer, virtual: true
    field :activity_title, :string, virtual: true
    field :page_title, :string, virtual: true
    field :graded, :boolean, virtual: true
    field :user, :any, virtual: true
    field :total_count, :integer, virtual: true

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
      :aggregate_score,
      :aggregate_out_of,
      :custom_scores,
      :lifecycle_state,
      :date_evaluated,
      :date_submitted,
      :scoreable,
      :transformed_model,
      :cleanup,
      :resource_attempt_id,
      :resource_id,
      :revision_id,
      :group_id,
      :survey_id,
      :selection_id
    ])
    |> validate_required([
      :attempt_guid,
      :attempt_number,
      :resource_attempt_id,
      :resource_id,
      :revision_id
    ])
  end
end
