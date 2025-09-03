defmodule Oli.Tags.SectionTag do
  @moduledoc """
  Join table schema for the many-to-many relationship between sections and tags.

  This table handles tags for both regular sections (type: :enrollable) and
  products/blueprints (type: :blueprint) since products are sections with
  type: :blueprint.
  """

  use Ecto.Schema

  @primary_key false
  schema "section_tags" do
    belongs_to :section, Oli.Delivery.Sections.Section, primary_key: true
    belongs_to :tag, Oli.Tags.Tag, primary_key: true
    timestamps(type: :utc_datetime)
  end
end
