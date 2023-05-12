defmodule Oli.Delivery.DeliverySetting do
  use Ecto.Schema

  import Ecto.Changeset

  schema "delivery_settings" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource

    embeds_one :collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig, on_replace: :update

    # assessment settings
    field(:end_date, :utc_datetime)
    field :max_attempts, :integer, default: 0
    field :retake_mode, Ecto.Enum, values: [:normal, :targeted], default: :normal
    field :late_submit, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :late_start, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :time_limit, :integer, default: 0
    field :grace_period, :integer, default: 0
    belongs_to :scoring_strategy, Oli.Resources.ScoringStrategy
    field :review_submission, Ecto.Enum, values: [:allow, :disallow], default: :allow
    field :feedback_mode, Ecto.Enum, values: [:allow, :disallow, :scheduled], default: :allow
    field :feedback_scheduled_date, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :user_id,
      :section_id,
      :resource_id,
      :end_date,
      :max_attempts,
      :retake_mode,
      :late_submit,
      :late_start,
      :time_limit,
      :grace_period,
      :scoring_strategy_id,
      :review_submission,
      :feedback_mode,
      :feedback_scheduled_date,
    ])
    |> cast_embed(:collab_space_config)
  end
end
