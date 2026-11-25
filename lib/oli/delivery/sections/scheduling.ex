defmodule Oli.Delivery.Sections.Scheduling do
  @moduledoc """
  Provides the read operations for the "soft-schedule" of a course section. The schedule is
  written by `Oli.Delivery.Sections.Audited.update_schedule/4` and `clear_schedule/2`.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResourceDepot

  @doc """
  For a given course section, return a list of all soft schedulable
  section resources (that is, all containers and pages).
  """
  def retrieve(%Section{id: section_id}, filter_resource_type \\ false) do
    SectionResourceDepot.retrieve_schedule(section_id, filter_resource_type)
  end

  @doc false
  # Validates and prepares the schedule `updates` of `Oli.Delivery.Sections.Audited.update_schedule/4`:
  # each update must have "id", "scheduling_type", "start_date", "end_date",
  # "manually_scheduled", and "removed_from_schedule" (atom or string keys; other attributes
  # are ignored). Dates are read in `timezone`, at `preferred_scheduling_time` when they have
  # no time. Returns `{:ok, sql, params, ids}` for one `UPDATE` of the section resources
  # (`$1` is the section ID) that returns the written schedule of each row, `{:ok, :empty}`, or
  # `{:error, :missing_update_parameters}`.
  def update_statement(updates, timezone, preferred_scheduling_time) do
    case is_valid_update?(updates) do
      false ->
        {:error, :missing_update_parameters}

      true ->
        case build_values_params(updates, timezone, preferred_scheduling_time) do
          {[], []} ->
            {:ok, :empty}

          {values, params} ->
            sql = """
              UPDATE section_resources
              SET
                scheduling_type = batch_values.scheduling_type,
                start_date = batch_values.start_date,
                end_date = batch_values.end_date,
                manually_scheduled = batch_values.manually_scheduled,
                removed_from_schedule = batch_values.removed_from_schedule,
                updated_at = NOW()
              FROM (
                  VALUES #{Enum.join(values, ",")}
              ) AS batch_values (id, scheduling_type, start_date, end_date, manually_scheduled, removed_from_schedule)
              WHERE section_resources.id = batch_values.id and section_resources.section_id = $1
              RETURNING section_resources.id, section_resources.scheduling_type,
                section_resources.start_date, section_resources.end_date,
                section_resources.manually_scheduled, section_resources.removed_from_schedule
            """

            {:ok, sql, params, Enum.map(updates, &to_id(val(&1, :id)))}
        end
    end
  end

  defp to_id(id) when is_integer(id), do: id
  defp to_id(id) when is_binary(id), do: String.to_integer(id)

  @doc """
  Check if a course section has any resources that have been scheduled.
  """
  @spec has_scheduled_resources?(section_id :: integer) :: boolean
  def has_scheduled_resources?(section_id) do
    SectionResourceDepot.has_scheduled_resources?(section_id)
  end

  defp is_valid_update?(updates) do
    keys = [
      "id",
      "scheduling_type",
      "start_date",
      "end_date",
      "manually_scheduled",
      "removed_from_schedule"
    ]

    atoms = Enum.map(keys, fn k -> String.to_existing_atom(k) end)

    both = Enum.zip(keys, atoms)

    Enum.all?(updates, fn u ->
      Enum.all?(both, fn {k, a} -> Map.has_key?(u, k) or Map.has_key?(u, a) end)
    end)
  end

  defp parse_date(nil, _, _), do: nil

  defp parse_date(date_time_str, timezone, preferred_scheduling_time) do
    # From the front end we can receive two forms of date time strings:
    # 1. "2019-01-01 00:00:00"
    # 2. "2019-01-01"

    # If the date_time_str contains a space, then we know it is of form 1.
    case String.contains?(date_time_str, " ") do
      true ->
        [date_str, time_str] = String.split(date_time_str, " ")

        [y, m, d] =
          String.split(date_str, "-")
          |> Enum.map(fn s -> String.to_integer(s) end)

        [h, n, s] =
          String.split(time_str, ":")
          |> Enum.map(fn s -> String.to_integer(s) end)

        {:ok, date} = Date.new(y, m, d)
        {:ok, time} = Time.new(h, n, s)

        {:ok, date_time} = DateTime.new(date, time, timezone)
        {:ok, date_time} = DateTime.shift_zone(date_time, "Etc/UTC")
        DateTime.truncate(date_time, :second)

      false ->
        [y, m, d] =
          String.split(date_time_str, "-")
          |> Enum.map(fn s -> String.to_integer(s) end)

        {:ok, date} = Date.new(y, m, d)

        time =
          if preferred_scheduling_time == nil,
            do: Time.new!(23, 59, 59),
            else: preferred_scheduling_time

        {:ok, date_time} = DateTime.new(date, time, timezone)
        {:ok, date_time} = DateTime.shift_zone(date_time, "Etc/UTC")
        DateTime.truncate(date_time, :second)
    end
  end

  defp build_values_params(updates, timezone, preferred_scheduling_time) do
    {values, params, _} =
      Enum.reduce(updates, {[], [], 1}, fn sr, {values, params, i} ->
        {
          values ++
            [
              "($#{i + 1}::bigint, $#{i + 2}, $#{i + 3}::timestamp, $#{i + 4}::timestamp, $#{i + 5}::boolean, $#{i + 6}::boolean)"
            ],
          params ++
            [
              val(sr, :id),
              val(sr, :scheduling_type),
              val(sr, :start_date) |> parse_date(timezone, preferred_scheduling_time),
              val(sr, :end_date) |> parse_date(timezone, preferred_scheduling_time),
              val(sr, :manually_scheduled),
              val(sr, :removed_from_schedule)
            ],
          i + 6
        }
      end)

    {values, params}
  end

  # support both atom and string keys
  defp val(sr, atom) do
    case Map.get(sr, atom) do
      nil -> Map.get(sr, Atom.to_string(atom))
      v -> v
    end
  end
end
