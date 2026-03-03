defmodule Oli.InstructorDashboard.InstructorDashboardState do
  @moduledoc """
  Persists instructor-specific dashboard state for a section enrollment.

  Each record is keyed by `enrollment_id` and currently stores the
  instructor's `last_viewed_scope` for the `Insights / Dashboard` tab,
  using values like `"course"` or `"container:123"`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Enrollment

  @type t :: %__MODULE__{
          id: integer() | nil,
          enrollment_id: integer() | nil,
          enrollment: Enrollment | Ecto.Association.NotLoaded.t() | nil,
          last_viewed_scope: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "instructor_dashboard_states" do
    belongs_to :enrollment, Enrollment
    field :last_viewed_scope, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds the changeset for persisted instructor dashboard state.
  """
  def changeset(instructor_dashboard_state, attrs) do
    instructor_dashboard_state
    |> cast(attrs, [:enrollment_id, :last_viewed_scope])
    |> validate_required([:enrollment_id, :last_viewed_scope])
    |> assoc_constraint(:enrollment)
    |> unique_constraint(:enrollment_id)
  end
end
