defmodule Oli.InstructorDashboard do
  @moduledoc """
  Persistence helpers for instructor dashboard state.

  This module currently manages the per-enrollment dashboard state used to
  restore the instructor's last selected dashboard scope when they return to
  the `Insights / Dashboard` tab.
  """

  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo

  @type state_attrs ::
          %{required(:last_viewed_scope) => String.t()}
          | %{
              required(String.t()) => String.t()
            }

  @doc """
  Fetches the persisted dashboard state for an instructor enrollment.

  Returns the matching `InstructorDashboardState` record when `enrollment_id`
  is an integer, otherwise returns `nil`.
  """
  @spec get_state_by_enrollment_id(integer() | term()) :: InstructorDashboardState.t() | nil
  def get_state_by_enrollment_id(enrollment_id) when is_integer(enrollment_id) do
    Repo.get_by(InstructorDashboardState, enrollment_id: enrollment_id)
  end

  def get_state_by_enrollment_id(_), do: nil

  @doc """
  Creates or updates the persisted dashboard state for an instructor enrollment.

  The current stored state is limited to `last_viewed_scope`, but the schema is
  intended to grow as more dashboard UI state becomes persistent.
  """
  @spec upsert_state(integer(), state_attrs()) ::
          {:ok, InstructorDashboardState.t()} | {:error, Ecto.Changeset.t()}
  def upsert_state(enrollment_id, attrs) when is_integer(enrollment_id) and is_map(attrs) do
    last_viewed_scope = Map.get(attrs, :last_viewed_scope) || Map.get(attrs, "last_viewed_scope")

    %InstructorDashboardState{}
    |> InstructorDashboardState.changeset(%{
      enrollment_id: enrollment_id,
      last_viewed_scope: last_viewed_scope
    })
    |> Repo.insert(
      on_conflict: [
        set: [
          last_viewed_scope: last_viewed_scope,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      ],
      conflict_target: [:enrollment_id],
      returning: true
    )
  end
end
