defmodule Oli.Course.Family do
  use Ecto.Schema
  import Ecto.Changeset

  schema "families" do
    field :description, :string
    field :slug, :string
    field :title, :string

    timestamps()
  end

  @doc false
  def changeset(family, attrs) do
    family
    |> cast(attrs, [:title, :slug, :description])
    |> validate_required([:title, :slug, :description])
  end
end
