defmodule Oli.Lti_1p3.Nonce do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nonces" do
    field :value, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [:value])
    |> validate_required([:value])
    |> unique_constraint(:value)
  end
end
