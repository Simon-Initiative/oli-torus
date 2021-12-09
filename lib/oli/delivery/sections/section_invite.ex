defmodule Oli.Delivery.Sections.SectionInvite do
  use Ecto.Schema
  import Ecto.Changeset
  alias Oli.Utils.Slug

  schema "section_invites" do
    belongs_to :section, Oli.Delivery.Sections.Section
    field :slug, :string
    field :date_expires, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section_invite, attrs \\ %{}) do
    section_invite
    |> cast(attrs, [:section_id, :slug, :date_expires])
    |> validate_required([:section_id, :date_expires])
    |> Slug.update_never_seedless("section_invites")
    |> validate_required([:slug])
    |> unique_constraint(:slug, name: :section_invites_slug_unique_index)
  end
end
