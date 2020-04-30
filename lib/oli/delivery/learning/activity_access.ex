defmodule Oli.Delivery.Learning.ActivityAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_access" do
    field :access_count, :integer
    field :date_finished, :utc_datetime
    field :finished_late, :boolean, default: false
    field :last_accessed, :utc_datetime
    field :resource_slug, :string
    field :user_id, :string

    belongs_to :section, Oli.Delivery.Sections.Section
    has_one :score, Oli.Delivery.Learning.Score
    has_one :feedback, Oli.Delivery.Learning.Feedback
    has_many :activity_attempts, Oli.Delivery.Learning.ActivityAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity_access, attrs) do
    activity_access
    |> cast(attrs, [:user_id, :section_id, :resource_slug, :access_count, :last_accessed, :date_finished, :finished_late])
    |> validate_required([:user_id, :section, :resource_slug, :last_accessed])
  end
end
