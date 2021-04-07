defmodule Oli.Resources.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    has_many :resource_revisions, Oli.Resources.Revision

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [])
    |> validate_required([])
  end
end
