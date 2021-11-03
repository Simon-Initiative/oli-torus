defmodule Oli.Delivery.Gating.GatingCondition do
  @moduledoc """
  GatingCondition represents a condition which will be evaluated at delivery
  to determine a user's ability to access a resource
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "gating_conditions" do
    field :type, Ecto.Enum,
      values: [
        :start_datetime,
        :end_datetime
      ]

    # data used by the condition evaluator, e.g. start or end datetime, a list of
    # resource_ids, etc.
    field :data, :map

    belongs_to :resource, Oli.Resources.Resource
    belongs_to :section, Oli.Delivery.Sections.Section

    # optionally, this condition can be associated with a specific user
    belongs_to :user, Oli.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gating_condition, attrs) do
    gating_condition
    |> cast(attrs, [:type, :data, :resource_id, :section_id, :user_id])
    |> validate_required([:type, :data, :resource_id, :section_id])
  end
end
