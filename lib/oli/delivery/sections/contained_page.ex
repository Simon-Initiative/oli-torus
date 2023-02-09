defmodule Oli.Delivery.Sections.ContainedPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.SectionResource

  schema "contained_pages" do

    belongs_to :container, SectionResource
    belongs_to :page, SectionResource

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contained_page, attrs) do
    contained_page
    |> cast(attrs, [
      :container_id,
      :page_id
    ])
    |> validate_required([
      :container_id,
      :page_id
    ])
  end

end
