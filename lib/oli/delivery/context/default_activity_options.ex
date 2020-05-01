defmodule Oli.Delivery.Context.DefaultActivityOptions do
  use Ecto.Schema
  import Ecto.Changeset

  schema "default_activity_options" do
    field :max_attempts, :integer
    field :recommended_attempts, :integer
    field :resource_slug, :string
    field :scoring_model, :map
    field :time_limit, :integer

    belongs_to :publication, Oli.Publishing.Publication

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(default_activity_options, attrs) do
    default_activity_options
    |> cast(attrs, [:resource_slug, :max_attempts, :recommended_attempts, :scoring_model, :time_limit])
    |> validate_required([:resource_slug, :max_attempts, :recommended_attempts, :scoring_model, :time_limit])
  end
end
