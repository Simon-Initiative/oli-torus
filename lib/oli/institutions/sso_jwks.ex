defmodule Oli.Institutions.SsoJwks do
  use Ecto.Schema
  import Ecto.Changeset

  @string_field_limit 255

  schema "sso_jwks" do
    field :pem, :string
    field :typ, :string
    field :alg, :string
    field :kid, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sso_jwks, attrs \\ %{}) do
    sso_jwks
    |> cast(attrs, [:pem, :typ, :alg, :kid])
    |> validate_required([:pem, :typ, :alg, :kid])
  end
end