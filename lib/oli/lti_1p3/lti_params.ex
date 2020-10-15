defmodule Oli.Lti_1p3.LtiParams do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_params" do
    field :key, :string
    field :data, :map
    field :exp, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [:key, :data, :exp])
    |> validate_required([:key, :data, :exp])
    |> unique_constraint(:key)
  end
end
