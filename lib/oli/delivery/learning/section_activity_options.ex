defmodule Oli.Delivery.Learning.SectionActivityOptions do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_activity_options" do
    field :attempts_permitted, :integer
    field :attempts_possible, :integer
    field :date_available, :utc_datetime
    field :date_due, :utc_datetime
    field :enable_hints, :boolean, default: false
    field :enable_review, :boolean, default: false
    field :feedback_mode, :map
    field :grace_period, :integer
    field :high_stakes, :boolean, default: false
    field :just_in_time, :boolean, default: false
    field :late_mode, :map
    field :password, :string
    field :resource_slug, :string
    field :score_visibility, :map
    field :scoring_model, :map
    field :section_slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_activity_options, attrs) do
    section_activity_options
    |> cast(attrs, [:section_slug, :resource_slug, :high_stakes, :date_available, :date_due, :just_in_time, :score_visibility, :attempts_permitted, :attempts_possible, :password, :grace_period, :late_mode, :enable_review, :enable_hints, :feedback_mode, :scoring_model])
    |> validate_required([:section_slug, :resource_slug])
  end
end
