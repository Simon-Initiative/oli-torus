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
        :schedule
      ]

    # data used by the condition evaluator, e.g. start or end datetime, a list of
    # resource_ids, etc.
    embeds_one :data, Oli.Delivery.Gating.GatingConditionData, on_replace: :delete

    belongs_to :resource, Oli.Resources.Resource
    belongs_to :section, Oli.Delivery.Sections.Section

    # optionally, this condition can be associated with a specific user
    belongs_to :user, Oli.Accounts.User

    field :total_count, :integer, virtual: true
    field :revision, :any, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gating_condition, attrs) do
    gating_condition
    |> cast(attrs, [:type, :resource_id, :section_id, :user_id])
    |> cast_embed(:data)
    |> validate_required([:type, :resource_id, :section_id])
  end
end
