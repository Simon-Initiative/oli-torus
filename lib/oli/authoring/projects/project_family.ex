defmodule Oli.Authoring.ProjectFamily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_families" do
    timestamps()
    field :slug, :string
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:slug])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end
end
