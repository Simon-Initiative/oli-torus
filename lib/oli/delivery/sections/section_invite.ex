defmodule Oli.Delivery.Sections.SectionInvite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "section_invites" do
    belongs_to :section, Oli.Delivery.Sections.Section
    field :slug, :string
    field :date_expires, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:section_id, :slug, :date_expires])
    |> validate_required([:section_id, :slug, :date_expires])
  end
end
