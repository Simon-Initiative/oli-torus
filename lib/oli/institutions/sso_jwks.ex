defmodule Oli.Institutions.SsoJwk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sso_jwks" do
    field :pem, :string
    field :typ, :string
    field :alg, :string
    field :kid, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sso_jwk, attrs \\ %{}) do
    sso_jwk
    |> cast(attrs, [:pem, :typ, :alg, :kid])
    |> validate_required([:pem, :typ, :alg, :kid])
  end
end
