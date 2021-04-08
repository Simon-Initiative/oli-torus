defmodule Oli.Features.FeatureState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feature_states" do
    field :state, Ecto.Enum, values: [:enabled, :disabled], default: :disabled

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feature, attrs \\ %{}) do
    feature
    |> cast(attrs, [
      :state
    ])
    |> validate_required([
      :state
    ])
  end
end
