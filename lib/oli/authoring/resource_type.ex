defmodule Oli.Authoring.ResourceType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_types" do
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
