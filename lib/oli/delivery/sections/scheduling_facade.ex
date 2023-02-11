defmodule Oli.Delivery.Sections.SchedulingFacade do

  @moduledoc """
  Provides a facade over the read and write operations for managing the "soft-scheduled"
  and a subset of "gated" hard schedule resources.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Sections.Scheduling
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections.SectionResource

  @doc """
  For a given course section, return a list of all schedulable
  section resources (that is, all containers and pages).
  """
  def retrieve(%Section{id: section_id} = section) do

    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    # Start with all soft scheduled resources, capturing their original ordering, but also
    # converting to a resource_id keyed map
    section_resources = Scheduling.retrieve(section)
    map = Enum.reduce(section_resources, %{}, fn sr, m -> Map.put(m, sr.resource_id, sr) end)

    # Now walk through the top-level schedule based gates, if any, updating the soft-schedule information
    # found it is corresponding section_resource record.
    map = Gating.list_gating_conditions(section_id, true)
    |> Enum.filter(fn gc -> gc.type == :schedule and is_nil(gc.data.start_datetime) end)
    |> Enum.reduce(map, fn gc, map ->

      case Map.get(map, gc.resource_id) do
        %SectionResource{resource_type_id: ^page_type_id} = sr ->

          sr = Map.put(sr, :scheduling_type, :due_by)
          |> Map.put(:start_date, nil)
          |> Map.put(:end_date, gc.data.end_datetime)

          Map.put(map, sr.resource_id, sr)

        _ ->
          map

      end
    end)

    Enum.map(section_resources, fn sr -> Map.get(map, sr.resource_id) end)

  end

  @doc """
  Persists both soft scheduled and gate changes.

  Returns a {:ok, num_rows} tuple, with num_rows indicating the number of rows
  updated - or a {:error, error} tuple.
  """
  def update(%Section{id: section_id} = section, updates, timezone) do

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    sr_map = Scheduling.retrieve(section)
    |> Enum.reduce(%{}, fn sr, m -> Map.put(m, sr.id, sr) end)

    gc_map = current_schedule_gates_as_map(section_id)

    Enum.reduce(updates, {[], [], [], []}, fn u, {sr_updates, gc_updates, gc_inserts, gc_deletes} ->

      existing_sr = Map.get(sr_map, val(u, :id))

      case val(u, :scheduling_type) do
        "due_by" ->
          # prep the sr update request to match it's previous scheduling_type, and truncate off
          # the time portion, if present


          updated = replace(u, :scheduling_type, existing_sr.scheduling_type |> Atom.to_string)
          |> truncate_times()

          # Determine if this is a gating condition update or requires an insert
          case Map.get(gc_map, existing_sr.resource_id) do
            nil ->

              end_date = val(u, :end_date) |> parse_date(timezone)

              insert = %{
                type: :schedule,
                graded_resource_policy: :allows_review,
                data: %Oli.Delivery.Gating.GatingConditionData{start_datetime: nil, end_datetime: end_date, resource_id: nil, minimum_percentage: nil},
                resource_id: Map.get(existing_sr, :resource_id),
                section_id: section_id,
                user_id: nil,
                parent_id: nil,
                updated_at: now,
                inserted_at: now
              }

              {[updated | sr_updates], gc_updates, [insert | gc_inserts], gc_deletes}
            gc ->
              {[updated | sr_updates], [%{id: gc.id, end_date: val(u, :end_date)} | gc_updates], gc_inserts, gc_deletes}
          end

        _ ->
          # See if there is an existing schedule gate for this resource that
          # we need to delete

          case Map.get(gc_map, existing_sr.resource_id) do
            nil ->
              {[u | sr_updates], gc_updates, gc_inserts, gc_deletes}
            gc ->
              {[u | sr_updates], gc_updates, gc_inserts, [gc | gc_deletes]}
          end


      end
    end)
    |> persist_all_changes(section, timezone)

  end

  defp persist_all_changes({adjusted_updates, gc_updates, gc_inserts, gc_deletes}, section, timezone) do
    Oli.Repo.transaction(fn ->
      with {:ok, _} <- delete_gating_conditions(gc_deletes),
           {:ok, _} <- insert_gating_conditions(gc_inserts),
           {:ok, _} <- update_gating_conditions(gc_updates, timezone),
           {:ok, count} <- Scheduling.update(section, adjusted_updates) do
        count
      end
    end)
  end

  defp delete_gating_conditions([]), do: {:ok, 0}
  defp delete_gating_conditions(deletes) do
    ids = Enum.map(deletes, fn d -> d.id end)
    {:ok, Oli.Repo.delete_all(from(gc in GatingCondition, where: gc.id in ^ids))}
  end

  defp insert_gating_conditions([]), do: {:ok, 0}
  defp insert_gating_conditions(inserts) do
    {:ok, Oli.Repo.insert_all(GatingCondition, inserts)}
  end

  defp current_schedule_gates_as_map(section_id) do
    Gating.list_gating_conditions(section_id, true)
    |> Enum.filter(fn gc -> gc.type == :schedule and is_nil(gc.data.start_datetime) end)
    |> Enum.reduce(%{}, fn gc, map -> Map.put(map, gc.resource_id, gc) end)
  end

  defp val(sr, atom) do
    case Map.get(sr, atom) do
      nil -> Map.get(sr, Atom.to_string(atom))
      v -> v
    end
  end

  defp replace(sr, atom, value) do
    case Map.get(sr, atom) do
      nil -> Map.put(sr, Atom.to_string(atom), value)
      _ -> Map.put(sr, atom, value)
    end
  end

  defp truncate_time(sr, atom) do

    v = val(sr, atom)

    case v do
      nil -> sr
      _ -> case String.split(v, " ") do
        [date, _time] -> replace(sr, atom, date)
        _ -> sr
      end
    end

  end

  defp truncate_times(sr) do
    truncate_time(sr, :start_date)
    |> truncate_time(:end_date)
  end

  defp update_gating_conditions([], _), do: {:ok, 0}
  defp update_gating_conditions(updates, timezone) do
    case build_values_params(updates, timezone) do
      {[], []} ->
        {:ok, 0}

      {values, params} ->
        values = Enum.join(values, ",")

        sql = """
          UPDATE gating_conditions
          SET
            data = batch_values.data,
            updated_at = NOW()
          FROM (
              VALUES #{values}
          ) AS batch_values (id, data)
          WHERE gating_conditions.id = batch_values.id
        """

        case Ecto.Adapters.SQL.query(Oli.Repo, sql, params) do
          {:ok, %{num_rows: num_rows}} -> {:ok, num_rows}
          e -> e
        end
    end
  end

  defp parse_date(nil, _), do: nil
  defp parse_date(date_time_str, timezone) do

    [date_str, time_str] = String.split(date_time_str, " ")

    [y, m, d] = String.split(date_str, "-")
    |> Enum.map(fn s -> String.to_integer(s) end)

    [h, n, s] = String.split(time_str, ":")
    |> Enum.map(fn s -> String.to_integer(s) end)

    {:ok, date} = Date.new(y, m, d)
    {:ok, time} = Time.new(h, n, s)

    {:ok, date_time} = DateTime.new(date, time, timezone)
    DateTime.truncate(date_time, :second)

  end

  defp build_values_params(updates, timezone) do
    {values, params, _} = Enum.reduce(updates, {[], [], 0}, fn sr, {values, params, i} ->
      {
        values ++
          [
            "($#{i + 1}::bigint, $#{i + 2}::jsonb)"
          ],
        params ++
          [
            val(sr, :id),
            %{
              start_datetime: nil,
              end_datetime: val(sr, :end_date) |> parse_date(timezone),
              resource_id: nil,
              minimum_percentage: nil
            }
          ],
        i + 2
      }
    end)

    {values, params}
  end

end
