defmodule Oli.Delivery.Sections.ContainedObjective do
  @moduledoc """
  The ContainedObjective schema represents an association between section containers and objectives linked to the pages within them.
  It is created for optimization purposes since it provides a fast way of retrieving the objectives associated to the containers of a section.

  Given a section, each objective will have as many entries in the table as containers it is linked to.
  There will be always at least one entry per objective with the container_id being nil, which represents the inclusion of the objective in the root container.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Resource

  schema "contained_objectives" do
    belongs_to(:section, Section)
    belongs_to(:container, Resource)
    belongs_to(:objective, Resource)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contained_page, attrs) do
    contained_page
    |> cast(attrs, [
      :section_id,
      :container_id,
      :objective_id
    ])
    |> validate_required([
      :section_id,
      :container_id,
      :objective_id
    ])
  end
end
