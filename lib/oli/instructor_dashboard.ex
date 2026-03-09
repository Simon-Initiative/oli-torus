defmodule Oli.InstructorDashboard do
  @moduledoc """
  Persistence helpers for instructor dashboard state.

  This module currently manages the per-enrollment dashboard state used to
  restore the instructor's last selected dashboard scope when they return to
  the `Insights / Dashboard` tab, along with enrollment-scoped layout
  preferences for dashboard sections.
  """

  require Logger

  alias Ecto.Changeset
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo
  alias Appsignal

  @type state_attrs ::
          %{
            optional(:last_viewed_scope) => String.t() | nil,
            optional(:section_order) => [String.t()] | nil,
            optional(:collapsed_section_ids) => [String.t()] | nil
          }
          | %{optional(String.t()) => String.t() | [String.t()] | nil}

  @type resolved_layout :: %{
          section_order: [String.t()],
          collapsed_section_ids: [String.t()]
        }

  @default_last_viewed_scope "course"
  @save_failure_metric "oli.instructor_dashboard.layout.save_failure"
  @restore_failure_metric "oli.instructor_dashboard.layout.restore_failure"

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

  Missing attributes preserve the current persisted value when a state row
  already exists. New rows default `last_viewed_scope` to `"course"` so
  layout-only updates can be persisted safely.
  """
  @spec upsert_state(integer(), state_attrs()) ::
          {:ok, InstructorDashboardState.t()} | {:error, Ecto.Changeset.t()}
  def upsert_state(enrollment_id, attrs) when is_integer(enrollment_id) and is_map(attrs) do
    do_upsert_state(enrollment_id, attrs, get_state_by_enrollment_id(enrollment_id))
  end

  defp do_upsert_state(enrollment_id, attrs, current_state) do
    state =
      case current_state do
        %InstructorDashboardState{} = state -> state
        nil -> %InstructorDashboardState{enrollment_id: enrollment_id}
      end

    attrs =
      normalized_state_attrs(enrollment_id, attrs, current_state)
      |> Map.put(:enrollment_id, enrollment_id)

    result =
      state
      |> InstructorDashboardState.changeset(attrs)
      |> Repo.insert_or_update()

    case result do
      {:error, %Changeset{} = changeset} ->
        maybe_retry_conflicted_insert(changeset, enrollment_id, attrs, current_state)

      _ ->
        maybe_track_save_failure(result, enrollment_id, attrs)
    end
  end

  @doc """
  Resolves persisted section layout against the currently visible dashboard sections.

  Unknown persisted ids are ignored, duplicate ids are collapsed to the first
  occurrence, and newly visible sections are appended in default order.
  """
  @spec resolve_section_layout(InstructorDashboardState.t() | nil, [String.t()]) ::
          resolved_layout()
  def resolve_section_layout(state, default_section_ids) when is_list(default_section_ids) do
    default_section_ids = Enum.uniq(default_section_ids)
    valid_section_ids = MapSet.new(default_section_ids)

    persisted_order =
      state
      |> layout_value(:section_order)
      |> filter_known_ids(valid_section_ids)
      |> Enum.uniq()

    collapsed_section_ids =
      state
      |> layout_value(:collapsed_section_ids)
      |> filter_known_ids(valid_section_ids)
      |> Enum.uniq()

    maybe_track_restore_failure(state, default_section_ids)

    %{
      section_order:
        persisted_order ++ Enum.reject(default_section_ids, &(&1 in persisted_order)),
      collapsed_section_ids: collapsed_section_ids
    }
  end

  def resolve_section_layout(_state, _default_section_ids) do
    maybe_track_restore_failure(nil, [])

    %{
      section_order: [],
      collapsed_section_ids: []
    }
  end

  defp normalized_state_attrs(enrollment_id, attrs, current_state) do
    normalized_attrs = %{
      last_viewed_scope:
        layout_attr(attrs, :last_viewed_scope) ||
          current_value(current_state, :last_viewed_scope) ||
          @default_last_viewed_scope,
      section_order:
        normalize_string_list(
          layout_attr(attrs, :section_order),
          current_value(current_state, :section_order, [])
        ),
      collapsed_section_ids:
        normalize_string_list(
          layout_attr(attrs, :collapsed_section_ids),
          current_value(current_state, :collapsed_section_ids, [])
        )
    }

    if malformed_layout_attrs?(attrs) do
      track_save_failure(enrollment_id, %{invalid_layout_payload: true})
    end

    normalized_attrs
  end

  defp layout_attr(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp current_value(nil, _field), do: nil
  defp current_value(state, field), do: Map.get(state, field)

  defp current_value(nil, _field, default), do: default
  defp current_value(state, field, _default), do: Map.get(state, field)

  defp normalize_string_list(nil, fallback), do: fallback

  defp normalize_string_list(value, fallback) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      value
    else
      fallback
    end
  end

  defp normalize_string_list(_value, fallback), do: fallback

  defp maybe_retry_conflicted_insert(changeset, enrollment_id, attrs, current_state) do
    if is_nil(current_state) and enrollment_unique_conflict?(changeset) do
      do_upsert_state(enrollment_id, attrs, get_state_by_enrollment_id(enrollment_id))
    else
      maybe_track_save_failure({:error, changeset}, enrollment_id, attrs)
    end
  end

  defp maybe_track_save_failure({:error, _} = result, enrollment_id, attrs) do
    track_save_failure(enrollment_id, attrs)
    result
  end

  defp maybe_track_save_failure(result, _enrollment_id, _attrs), do: result

  defp maybe_track_restore_failure(%InstructorDashboardState{} = state, default_section_ids) do
    if malformed_persisted_layout?(state, default_section_ids) do
      track_restore_failure(state.enrollment_id, :invalid_persisted_layout)
    end
  end

  defp maybe_track_restore_failure(_state, _default_section_ids), do: :ok

  defp malformed_persisted_layout?(state, default_section_ids) do
    duplicate_ids?(state.section_order) ||
      duplicate_ids?(state.collapsed_section_ids) ||
      !is_list(default_section_ids)
  end

  defp malformed_layout_attrs?(attrs) do
    invalid_string_list?(layout_attr(attrs, :section_order)) ||
      invalid_string_list?(layout_attr(attrs, :collapsed_section_ids))
  end

  defp invalid_string_list?(nil), do: false
  defp invalid_string_list?(value) when is_list(value), do: !Enum.all?(value, &is_binary/1)
  defp invalid_string_list?(_value), do: true

  defp duplicate_ids?(value) when is_list(value), do: Enum.uniq(value) != value
  defp duplicate_ids?(_value), do: false

  defp enrollment_unique_conflict?(%Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:enrollment_id, {_message, details}} -> details[:constraint] == :unique
      _ -> false
    end)
  end

  defp layout_value(nil, _field), do: []

  defp layout_value(state, field) do
    case Map.get(state, field) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  defp filter_known_ids(ids, valid_section_ids) do
    Enum.filter(ids, fn id -> is_binary(id) and MapSet.member?(valid_section_ids, id) end)
  end

  defp track_save_failure(enrollment_id, attrs) do
    metadata = %{
      enrollment_id: enrollment_id,
      keys: Map.keys(attrs) |> Enum.map(&to_string/1) |> Enum.sort()
    }

    Logger.warning("Failed to persist instructor dashboard layout", metadata)
    Appsignal.increment_counter(@save_failure_metric, 1, %{source: "instructor_dashboard"})
  end

  defp track_restore_failure(enrollment_id, reason) do
    Logger.warning("Invalid instructor dashboard layout restore", %{
      enrollment_id: enrollment_id,
      reason: reason
    })

    Appsignal.increment_counter(@restore_failure_metric, 1, %{reason: to_string(reason)})
  end
end
