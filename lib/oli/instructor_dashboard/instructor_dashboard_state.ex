defmodule Oli.InstructorDashboard.InstructorDashboardState do
  @moduledoc """
  Persists instructor-specific dashboard state for a section enrollment.

  Each record is keyed by `enrollment_id` and currently stores the
  instructor's `last_viewed_scope` for the `Insights / Dashboard` tab,
  using values like `"course"` or `"container:123"`, plus layout
  preferences for section ordering and collapse state.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Enrollment

  @type t :: %__MODULE__{
          id: integer() | nil,
          enrollment_id: integer() | nil,
          enrollment: Enrollment | Ecto.Association.NotLoaded.t() | nil,
          last_viewed_scope: String.t() | nil,
          section_order: [String.t()],
          collapsed_section_ids: [String.t()],
          section_tile_layouts: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "instructor_dashboard_states" do
    belongs_to :enrollment, Enrollment
    field :last_viewed_scope, :string
    field :section_order, {:array, :string}, default: []
    field :collapsed_section_ids, {:array, :string}, default: []
    field :section_tile_layouts, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds the changeset for persisted instructor dashboard state.
  """
  def changeset(instructor_dashboard_state, attrs) do
    instructor_dashboard_state
    |> cast(attrs, [
      :enrollment_id,
      :last_viewed_scope,
      :section_order,
      :collapsed_section_ids,
      :section_tile_layouts
    ])
    |> validate_required([:enrollment_id, :last_viewed_scope])
    |> validate_unique_ids(:section_order)
    |> validate_unique_ids(:collapsed_section_ids)
    |> assoc_constraint(:enrollment)
    |> unique_constraint(:enrollment_id)
  end

  defp validate_unique_ids(changeset, field) do
    validate_change(changeset, field, fn ^field, ids ->
      if Enum.uniq(ids) == ids do
        []
      else
        [{field, "must not contain duplicate ids"}]
      end
    end)
  end
end
