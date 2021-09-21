defmodule Oli.Interop.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field :status, Ecto.Enum, values: [:enabled, :disabled], default: :enabled
    field :hash, :binary
    field :hint, :binary
    field :payments_enabled, :boolean, default: true
    field :products_enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feature, attrs \\ %{}) do
    feature
    |> cast(attrs, [
      :status,
      :hash,
      :hint,
      :payments_enabled,
      :products_enabled
    ])
    |> validate_required([
      :status,
      :hash,
      :hint
    ])
  end
end
