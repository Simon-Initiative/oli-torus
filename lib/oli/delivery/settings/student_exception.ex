defmodule Oli.Delivery.Settings.StudentException do
  use Ecto.Schema

  import Ecto.Changeset

  schema "delivery_settings" do
    belongs_to(:user, Oli.Accounts.User)
    belongs_to(:section, Oli.Delivery.Sections.Section)
    belongs_to(:resource, Oli.Resources.Resource)

    embeds_one(:collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig,
      on_replace: :delete
    )

    embeds_one(:explanation_strategy, Oli.Resources.ExplanationStrategy, on_replace: :delete)

    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)
    field(:password, :string)
    field(:max_attempts, :integer)
    field(:retake_mode, Ecto.Enum, values: [:normal, :targeted])
    field(:assessment_mode, Ecto.Enum, values: [:traditional, :one_at_a_time])
    field :batch_scoring, :boolean
    field :replacement_strategy, Ecto.Enum, values: [:none, :dynamic]

    field(:late_submit, Ecto.Enum, values: [:allow, :disallow])
    field(:late_start, Ecto.Enum, values: [:allow, :disallow])
    field(:time_limit, :integer)
    field(:grace_period, :integer)
    field(:scoring_strategy_id, :integer)
    field(:review_submission, Ecto.Enum, values: [:allow, :disallow])
    field(:feedback_mode, Ecto.Enum, values: [:allow, :disallow, :scheduled])
    field(:feedback_scheduled_date, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}, required_fields \\ []) do
    post
    |> cast(attrs, [
      :user_id,
      :section_id,
      :resource_id,
      :start_date,
      :end_date,
      :password,
      :max_attempts,
      :retake_mode,
      :assessment_mode,
      :batch_scoring,
      :replacement_strategy,
      :late_submit,
      :late_start,
      :time_limit,
      :grace_period,
      :scoring_strategy_id,
      :review_submission,
      :feedback_mode,
      :feedback_scheduled_date
    ])
    |> cast_embed(:explanation_strategy)
    |> cast_embed(:collab_space_config)
    |> validate_required(required_fields)
  end
end
