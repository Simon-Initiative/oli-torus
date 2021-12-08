defmodule Oli.Lti.Nonce do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_nonces" do
    field :value, :string
    field :domain, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [:value, :domain])
    |> validate_required([:value])
    |> unique_constraint(:value, name: :value_domain_index)
  end
end
