defmodule Oli.Delivery.Sections.ContainedPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Resource

  schema "contained_pages" do

    belongs_to :section, Section
    belongs_to :container, Resource
    belongs_to :page, Resource

  end

  @doc false
  def changeset(contained_page, attrs) do
    contained_page
    |> cast(attrs, [
      :section_id,
      :container_id,
      :page_id
    ])
    |> validate_required([
      :section_id,
      :container_id,
      :page_id
    ])
  end

end
