defmodule Oli.Authoring.Resources.ResourceFamily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_families" do

    timestamps()
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [])
    |> validate_required([])
  end

end
