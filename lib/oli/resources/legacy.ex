defmodule Oli.Resources.Legacy do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :path, :string
    field :id, :string
  end

  def changeset(legacy, attrs \\ %{}) do
    legacy
    |> cast(attrs, [:path, :id])
  end
end
