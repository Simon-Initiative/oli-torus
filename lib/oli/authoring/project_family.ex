defmodule Oli.Authoring.ProjectFamily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_families" do
    timestamps()
    field :slug, :string
  end

  @doc false
  def changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [:slug])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end
end
