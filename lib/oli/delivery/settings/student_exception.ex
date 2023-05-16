defmodule Oli.Delivery.Settings.StudentException do
  use Ecto.Schema

  import Ecto.Changeset

  schema "delivery_settings" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource

    embeds_one :collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig, on_replace: :delete
    embeds_one :explanation_strategy, Oli.Resources.ExplanationStrategy, on_replace: :delete

    field :end_date, :utc_datetime, null: true
    field :password, :string, null: true
    field :max_attempts, :integer, null: true
    field :retake_mode, Ecto.Enum, values: [:normal, :targeted], null: true
    field :late_submit, Ecto.Enum, values: [:allow, :disallow], null: true
    field :late_start, Ecto.Enum, values: [:allow, :disallow], null: true
    field :time_limit, :integer, null: true
    field :grace_period, :integer, null: true
    field :scoring_strategy_id, :integer, null: true
    field :review_submission, Ecto.Enum, values: [:allow, :disallow], null: true
    field :feedback_mode, Ecto.Enum, values: [:allow, :disallow, :scheduled], null: true
    field :feedback_scheduled_date, :utc_datetime, null: true

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :user_id,
      :section_id,
      :resource_id,
      :end_date,
      :password,
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
    |> cast_embed(:explanation_strategy)
    |> cast_embed(:collab_space_config)
  end
end
