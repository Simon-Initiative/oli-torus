defmodule OliWeb.Dialogue.UserInput do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :content, :string
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [:content])
  end
end
