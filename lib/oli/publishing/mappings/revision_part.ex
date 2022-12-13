defmodule Oli.Publishing.RevisionPart do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revision_parts" do
    field :part_id, :string
    field :grading_approach, Ecto.Enum, values: [:automatic, :manual], default: :automatic
    belongs_to :revision, Oli.Resources.Revision
  end

  @doc false
  def changeset(revision_parts, attrs) do
    revision_parts
    |> cast(attrs, [:part_id, :grading_approach, :revision_id])
    |> validate_required([:part_id, :grading_approach, :revision_id])
  end
end
