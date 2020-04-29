defmodule Oli.Delivery.Learning.UserActivityOptions do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_activity_option" do
    field :date_available, :utc_datetime
    field :date_due, :utc_datetime
    field :grace_period, :integer
    field :high_stakes, :boolean, default: false
    field :just_in_time, :boolean, default: false
    field :late_mode, :map
    field :late_start, :boolean, default: false
    field :password, :string
    field :resource_slug, :string
    field :scoring_model, :map
    field :section_slug, :string
    field :time_limit, :integer
    field :user_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_activity_options, attrs) do
    user_activity_options
    |> cast(attrs, [:section_slug, :resource_slug, :user_id, :high_stakes, :date_available, :date_due, :just_in_time, :scoring_model, :password, :late_start, :time_limit, :grace_period, :late_mode])
    |> validate_required([:section_slug, :resource_slug, :user_id])
  end
end
