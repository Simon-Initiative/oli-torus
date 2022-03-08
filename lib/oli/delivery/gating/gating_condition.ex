defmodule Oli.Delivery.Gating.GatingCondition do
  @moduledoc """
  GatingCondition represents a condition which will be evaluated at delivery
  to determine a user's ability to access a resource
  """
  use Ecto.Schema
  import Ecto.Changeset

  @graded_resource_policies [
    :allows_nothing,
    :allows_review
  ]
  @default_graded_resource_policy :allows_review

  schema "gating_conditions" do
    field :type, Ecto.Enum,
      values: [
        :schedule,
        :always_open,
        :started,
        :finished
      ]

    # The ways in which this gate affects access to graded resources
    field :graded_resource_policy, Ecto.Enum,
      values: @graded_resource_policies,
      default: @default_graded_resource_policy

    # data used by the condition evaluator, e.g. start or end datetime, a list of
    # resource_ids, etc.
    embeds_one :data, Oli.Delivery.Gating.GatingConditionData, on_replace: :delete
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :section, Oli.Delivery.Sections.Section

    # optionally, this condition can be associated with a specific user and a parent gating condition
    belongs_to :user, Oli.Accounts.User
    belongs_to :parent, Oli.Delivery.Gating.GatingCondition

    field :total_count, :integer, virtual: true
    field :revision, :any, virtual: true

    timestamps(type: :utc_datetime)
  end

  @spec graded_resource_policies :: [:allows_nothing | :allows_review, ...]
  def graded_resource_policies, do: @graded_resource_policies

  @doc false
  def changeset(gating_condition, attrs) do
    gating_condition
    |> cast(attrs, [
      :type,
      :resource_id,
      :section_id,
      :user_id,
      :parent_id,
      :graded_resource_policy
    ])
    |> cast_embed(:data)
    |> validate_required([:type, :resource_id, :section_id, :graded_resource_policy])
  end
end
