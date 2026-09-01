defmodule Oli.LearningModel.LearningState do
  @moduledoc """
  Compact LKT-AOA state for one learner and one directly targeted learning objective.

  The composite key is the write and lock identity used by the bulk application
  transaction; this row intentionally stores model state, not attempt history or
  fitted coefficients.
  """

  use Ecto.Schema

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Resource

  @primary_key false
  schema "learning_states" do
    belongs_to(:section, Section, primary_key: true)
    belongs_to(:user, User, primary_key: true)
    belongs_to(:learning_objective, Resource, primary_key: true)

    field(:attempt_count, :integer, default: 0)
    field(:success_score, :float, default: 0.0)
    field(:failure_score, :float, default: 0.0)
    field(:recency_logit, :float, default: 0.0)
    field(:aoa, :float, default: 0.0)
    field(:unique_activity_part_count, :integer, default: 0)
    field(:confidence, :float, default: 0.0)

    timestamps(type: :utc_datetime)
  end
end
