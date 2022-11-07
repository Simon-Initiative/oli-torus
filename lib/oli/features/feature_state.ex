defmodule Oli.Features.FeatureState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:label, :string, autogenerate: false}
  schema "feature_states" do
    field :state, Ecto.Enum, values: [:enabled, :disabled], default: :disabled
  end

  @doc false
  def changeset(feature, attrs \\ %{}) do
    feature
    |> cast(attrs, [
      :label,
      :state
    ])
    |> validate_required([
      :label,
      :state
    ])
  end
end
