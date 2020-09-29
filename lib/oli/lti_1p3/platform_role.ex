defmodule Oli.Lti_1p3.PlatformRole do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :uri, :string
  end

  @doc false
  def changeset(platform_role, attrs \\ %{}) do
    platform_role
    |> cast(attrs, [:uri])
    |> validate_required([:uri])
  end

end
