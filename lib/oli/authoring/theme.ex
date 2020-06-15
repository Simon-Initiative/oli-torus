defmodule Oli.Authoring.Theme do
  use Ecto.Schema
  import Ecto.Changeset

  schema "themes" do
    field :name, :string
    field :url, :string
    field :default, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(theme, attrs \\ %{}) do
    theme
    |> cast(attrs, [:name, :url, :default])
    |> validate_required([:name, :url])
  end
end
