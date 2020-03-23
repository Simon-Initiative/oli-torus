defmodule Oli.Publishing.ResourceMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_mappings" do

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :revision, Oli.Resources.ResourceRevision

    timestamps()
  end

  @doc false
  def changeset(resource_mapping, attrs) do
    resource_mapping
    |> cast(attrs, [])
    |> validate_required([:publication, :resource, :revision])
  end
end
