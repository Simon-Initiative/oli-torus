defmodule Oli.InstructorDashboard do
  @moduledoc """
  Persistence helpers for instructor dashboard state.

  This module currently manages the per-enrollment dashboard state used to
  restore the instructor's last selected dashboard scope when they return to
  the `Insights / Dashboard` tab, along with enrollment-scoped layout
  preferences for dashboard sections.
  """

  require Logger
  import Ecto.Query, warn: false

  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo
  alias Appsignal

  @type state_attrs ::
          %{
            optional(:last_viewed_scope) => String.t() | nil,
            optional(:section_order) => [String.t()] | nil,
            optional(:collapsed_section_ids) => [String.t()] | nil,
            optional(:section_tile_layouts) => map() | nil
          }
          | %{optional(String.t()) => String.t() | [String.t()] | map() | nil}

  @type resolved_layout :: %{
          section_order: [String.t()],
          collapsed_section_ids: [String.t()],
          section_tile_layouts: %{optional(String.t()) => %{required(:split) => integer()}}
        }

  @default_last_viewed_scope "course"
  @default_section_tile_split 43
  @min_section_tile_split 30
  @max_section_tile_split 70
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
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      %InstructorDashboardState{}
      |> InstructorDashboardState.changeset(normalized_insert_state_attrs(enrollment_id, attrs))
      |> Repo.insert(
        conflict_target: [:enrollment_id],
        on_conflict: [set: upsert_conflict_updates(attrs, timestamp)],
        returning: true
      )
      |> maybe_track_save_failure(enrollment_id, attrs)

    result
  end

  @doc """
  Resolves persisted section layout against the currently visible dashboard sections.

  Unknown persisted ids are ignored, duplicate ids are collapsed to the first
  occurrence, and newly visible sections are appended in default order.
  """
  @spec resolve_section_layout(InstructorDashboardState.t() | map() | nil, [String.t()]) ::
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
      collapsed_section_ids: collapsed_section_ids,
      section_tile_layouts: resolve_section_tile_layouts(state, default_section_ids)
    }
  end

  def resolve_section_layout(_state, _default_section_ids) do
    maybe_track_restore_failure(nil, [])

    %{
      section_order: [],
      collapsed_section_ids: [],
      section_tile_layouts: %{}
    }
  end

  defp normalized_insert_state_attrs(enrollment_id, attrs) do
    normalized_attrs = %{
      enrollment_id: enrollment_id,
      last_viewed_scope: layout_attr(attrs, :last_viewed_scope) || @default_last_viewed_scope,
      section_order: normalize_string_list(layout_attr(attrs, :section_order), []),
      collapsed_section_ids:
        normalize_string_list(layout_attr(attrs, :collapsed_section_ids), []),
      section_tile_layouts:
        normalize_section_tile_layouts(layout_attr(attrs, :section_tile_layouts), %{})
    }

    if malformed_layout_attrs?(attrs) do
      track_save_failure(enrollment_id, %{invalid_layout_payload: true})
    end

    normalized_attrs
  end

  defp layout_attr(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp upsert_conflict_updates(attrs, timestamp) do
    [updated_at: timestamp]
    |> maybe_put_conflict_update(:last_viewed_scope, layout_attr(attrs, :last_viewed_scope))
    |> maybe_put_conflict_update(
      :section_order,
      normalize_update_string_list(layout_attr(attrs, :section_order))
    )
    |> maybe_put_conflict_update(
      :collapsed_section_ids,
      normalize_update_string_list(layout_attr(attrs, :collapsed_section_ids))
    )
    |> maybe_put_conflict_update(
      :section_tile_layouts,
      normalize_update_section_tile_layouts(layout_attr(attrs, :section_tile_layouts))
    )
  end

  defp maybe_put_conflict_update(updates, _field, nil), do: updates
  defp maybe_put_conflict_update(updates, field, value), do: [{field, value} | updates]

  defp normalize_string_list(nil, fallback), do: fallback

  defp normalize_string_list(value, fallback) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      value
    else
      fallback
    end
  end

  defp normalize_string_list(_value, fallback), do: fallback

  defp normalize_update_string_list(nil), do: nil

  defp normalize_update_string_list(value) when is_list(value),
    do: normalize_string_list(value, nil)

  defp normalize_update_string_list(_value), do: nil

  defp normalize_section_tile_layouts(nil, fallback), do: fallback

  defp normalize_section_tile_layouts(value, fallback) when is_map(value) do
    case Enum.reduce_while(value, %{}, fn
           {section_id, section_layout}, acc
           when is_binary(section_id) and is_map(section_layout) ->
             with {:ok, split} <- normalize_section_tile_split(section_layout) do
               {:cont, Map.put(acc, section_id, %{split: split})}
             else
               :error -> {:halt, :invalid}
             end

           _, _acc ->
             {:halt, :invalid}
         end) do
      :invalid -> fallback
      normalized -> normalized
    end
  end

  defp normalize_section_tile_layouts(_value, fallback), do: fallback

  defp normalize_update_section_tile_layouts(nil), do: nil

  defp normalize_update_section_tile_layouts(value) when is_map(value),
    do: normalize_section_tile_layouts(value, nil)

  defp normalize_update_section_tile_layouts(_value), do: nil

  defp normalize_section_tile_split(layout) when is_map(layout) do
    case Map.get(layout, :split) || Map.get(layout, "split") do
      split when is_integer(split) ->
        {:ok, clamp_section_tile_split(split)}

      _ ->
        :error
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
      invalid_section_tile_layouts?(state.section_tile_layouts, default_section_ids) ||
      !is_list(default_section_ids)
  end

  defp malformed_layout_attrs?(attrs) do
    invalid_string_list?(layout_attr(attrs, :section_order)) ||
      invalid_string_list?(layout_attr(attrs, :collapsed_section_ids)) ||
      invalid_section_tile_layouts?(layout_attr(attrs, :section_tile_layouts))
  end

  defp invalid_string_list?(nil), do: false
  defp invalid_string_list?(value) when is_list(value), do: !Enum.all?(value, &is_binary/1)
  defp invalid_string_list?(_value), do: true

  defp duplicate_ids?(value) when is_list(value), do: Enum.uniq(value) != value
  defp duplicate_ids?(_value), do: false

  defp invalid_section_tile_layouts?(nil), do: false

  defp invalid_section_tile_layouts?(value) do
    normalize_section_tile_layouts(value, :invalid) == :invalid
  end

  defp invalid_section_tile_layouts?(value, default_section_ids) do
    case normalize_section_tile_layouts(value, :invalid) do
      :invalid ->
        true

      normalized ->
        valid_section_ids = MapSet.new(default_section_ids)

        Enum.any?(normalized, fn {section_id, _layout} ->
          not MapSet.member?(valid_section_ids, section_id)
        end)
    end
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

  defp resolve_section_tile_layouts(state, default_section_ids) do
    valid_section_ids = MapSet.new(default_section_ids)

    persisted_layouts =
      case Map.get(state || %{}, :section_tile_layouts, %{}) do
        value when is_map(value) -> value
        _ -> %{}
      end
      |> normalize_section_tile_layouts(%{})
      |> Enum.filter(fn {section_id, _layout} ->
        MapSet.member?(valid_section_ids, section_id)
      end)
      |> Map.new()

    Enum.reduce(default_section_ids, %{}, fn section_id, acc ->
      Map.put(
        acc,
        section_id,
        Map.get(persisted_layouts, section_id, %{split: @default_section_tile_split})
      )
    end)
  end

  defp clamp_section_tile_split(split) do
    split
    |> max(@min_section_tile_split)
    |> min(@max_section_tile_split)
  end

  defp track_save_failure(enrollment_id, attrs) do
    metadata = [
      enrollment_id: enrollment_id,
      keys: Map.keys(attrs) |> Enum.map(&to_string/1) |> Enum.sort()
    ]

    Logger.warning("Failed to persist instructor dashboard layout", metadata)
    Appsignal.increment_counter(@save_failure_metric, 1, %{source: "instructor_dashboard"})
  end

  defp track_restore_failure(enrollment_id, reason) do
    Logger.warning(
      "Invalid instructor dashboard layout restore",
      enrollment_id: enrollment_id,
      reason: reason
    )

    Appsignal.increment_counter(@restore_failure_metric, 1, %{reason: to_string(reason)})
  end
end
