defmodule Oli.Delivery.Sections.SectionVisibility do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_visibilities" do
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :institution, Oli.Institutions.Institution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_visibility, attrs) do
    section_visibility
    |> cast(attrs, [:section_id, :institution_id])
    |> validate_required([:section_id, :institution_id])
  end
end
