defmodule Oli.Delivery.DeliveryPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section

  schema "delivery_policies" do
    field :assessment_scoring_model, Ecto.Enum,
      values: [:average, :highest, :lowest, :first_attempt, :last_attempt]

    field :assessment_late_submit_policy, Ecto.Enum,
      values: [:allowed, :allowed_with_approval, :not_allowed, :auto_submit]

    field :assessment_grace_period_sec, :integer
    field :assessment_time_limit_sec, :integer

    field :assessment_feedback_mode, Ecto.Enum,
      values: [:after_submit, :after_deadline, :instructor_released, :never]

    field :assessment_review_answers_policy, Ecto.Enum, values: [:allowed, :not_allowed]

    # number of attempts allowed, negative numbers may represent special handling
    # (-2) = recommended, (-1) = unlimited, 0+ = specific number
    field :assessment_num_attempts, :integer

    belongs_to :section, Section

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(delivery_policy, attrs \\ %{}) do
    delivery_policy
    |> cast(attrs, [
      :assessment_scoring_model,
      :assessment_late_submit_policy,
      :assessment_grace_period_sec,
      :assessment_time_limit_sec,
      :assessment_feedback_mode,
      :assessment_review_answers_policy,
      :assessment_num_attempts,
      :section_id,
      :user_group_id
    ])
    |> validate_required([:section_id])
  end
end
