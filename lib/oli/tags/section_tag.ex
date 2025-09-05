defmodule Oli.Tags.SectionTag do
  @moduledoc """
  Join table schema for the many-to-many relationship between sections and tags.

  This table handles tags for both regular sections (type: :enrollable) and
  products/blueprints (type: :blueprint) since products are sections with
  type: :blueprint.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "section_tags" do
    belongs_to :section, Oli.Delivery.Sections.Section, primary_key: true
    belongs_to :tag, Oli.Tags.Tag, primary_key: true
    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a section tag association.
  """
  def changeset(section_tag, attrs \\ %{}) do
    section_tag
    |> cast(attrs, [:section_id, :tag_id])
    |> validate_required([:section_id, :tag_id])
    |> unique_constraint([:section_id, :tag_id], name: :section_tags_pkey)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:tag_id)
  end
end
