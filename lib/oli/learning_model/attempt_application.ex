defmodule Oli.LearningModel.AttemptApplication do
  @moduledoc """
  Immutable idempotency claim for applying one PartAttempt to a learning model.

  This table deliberately has exactly three database fields and no standard Ecto
  timestamps. The source PartAttempt owns every other attempt attribute, while this
  row answers only whether the model transition has already been applied.
  """

  use Ecto.Schema

  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.LearningModel.ModelVersion

  @primary_key false
  schema "learning_model_attempt_applications" do
    belongs_to(:part_attempt, PartAttempt, primary_key: true)
    field(:learning_model_version, Ecto.Enum, values: ModelVersion.values())
    field(:applied_at, :utc_datetime)
  end
end
