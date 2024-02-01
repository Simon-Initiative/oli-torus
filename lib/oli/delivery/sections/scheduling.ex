defmodule Oli.Delivery.Sections.Scheduling do
  @moduledoc """
  Provides the read and write operations for managing the "soft-schedule" for a course section.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Oli.Publishing.PublishedResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Resources.Revision
  alias Oli.Repo

  @doc """
  For a given course section, return a list of all soft schedulable
  section resources (that is, all containers and pages).
  """
  def retrieve(%Section{id: section_id}, filter_resource_type \\ false) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()
    container_type_id = Oli.Resources.ResourceType.id_for_container()

    filter_by_resource_type =
      case filter_resource_type do
        :pages ->
          dynamic([sr, _s, _spp, _pr, rev], rev.resource_type_id == ^page_type_id)

        :containers ->
          dynamic([sr, _s, _spp, _pr, rev], rev.resource_type_id == ^container_type_id)

        _ ->
          dynamic(
            [sr, _s, _spp, _pr, rev],
            rev.resource_type_id == ^container_type_id or rev.resource_type_id == ^page_type_id
          )
      end

    query =
      SectionResource
      |> join(:left, [sr], s in Section, on: sr.section_id == s.id)
      |> join(:left, [_sr, s], spp in SectionsProjectsPublications, on: spp.section_id == s.id)
      |> join(:left, [_sr, _s, spp], pr in PublishedResource,
        on: pr.publication_id == spp.publication_id
      )
      |> join(:left, [_sr, _s, _spp, pr], rev in Revision, on: pr.revision_id == rev.id)
      |> where(
        [sr, s, spp, pr, rev],
        sr.project_id == spp.project_id and s.id == ^section_id and
          pr.resource_id == sr.resource_id
      )
      |> where(^filter_by_resource_type)
      |> select_merge([_sr, _s, _spp, _pr, rev], %{
        title: rev.title,
        resource_type_id: rev.resource_type_id,
        graded: rev.graded
      })

    Repo.all(query)
  end

  @doc """
  Persist scheduling updates to a list of section resources, for a given
  course section. The section must be specified here so that internally this
  function can guarantee that only those section resources that pertain to this
  course section can be edited.  The shape of the maps that are the elements
  within the updates list must at least contain attributes for "id", "scheduling_type",
  "start_date", "end_date" and "manually_scheduled". Other attributes will be ignored.

  Returns a {:ok, num_rows} tuple, with num_rows indicating the number of rows
  updated - or a {:error, error} tuple.
  """
  def update(
        %Section{id: section_id, preferred_scheduling_time: preferred_scheduling_time},
        updates,
        timezone
      ) do
    if is_valid_update?(updates) do
      case build_values_params(updates, timezone, preferred_scheduling_time) do
        {[], []} ->
          {:ok, 0}

        {values, params} ->
          values = Enum.join(values, ",")

          sql = """
            UPDATE section_resources
            SET
              scheduling_type = batch_values.scheduling_type,
              start_date = batch_values.start_date,
              end_date = batch_values.end_date,
              manually_scheduled = batch_values.manually_scheduled,
              updated_at = NOW()
            FROM (
                VALUES #{values}
            ) AS batch_values (id, scheduling_type, start_date, end_date, manually_scheduled)
            WHERE section_resources.id = batch_values.id and section_resources.section_id = $1
          """

          case Ecto.Adapters.SQL.query(Repo, sql, [section_id | params]) do
            {:ok, %{num_rows: num_rows}} -> {:ok, num_rows}
            e -> e
          end
      end
    else
      {:error, :missing_update_parameters}
    end
  end

  @doc """
  Clear the scheduling for all section resources for a given course section.
  """

  def clear(%Section{id: section_id}) do
    res =
      Multi.new()
      |> Multi.run(:section_resources_count, fn repo, changes ->
        count =
          get_section_resources_with_schedule(changes, section_id)
          |> repo.aggregate(:count, :id)

        {:ok, count}
      end)
      |> Multi.update_all(
        :updated_resources,
        &get_section_resources_with_schedule(&1, section_id),
        set: [start_date: nil, end_date: nil]
      )
      |> Repo.transaction()

    case res do
      {:error, _} ->
        {:error, :failed_to_clear_scheduling}

      {:ok,
       %{
         section_resources_count: resources_to_update_count,
         updated_resources: {updated_count, _}
       }}
      when resources_to_update_count == updated_count ->
        {:ok, updated_count}

      {:ok, _} ->
        {:error, :uncomplete_clear_scheduling}
    end
  end

  def get_section_resources_with_schedule(_changes, section_id) do
    from(
      sr in SectionResource,
      where:
        sr.section_id == ^section_id and (not is_nil(sr.start_date) or not is_nil(sr.end_date))
    )
  end

  defp is_valid_update?(updates) do
    keys = ["id", "scheduling_type", "start_date", "end_date", "manually_scheduled"]
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
              "($#{i + 1}::bigint, $#{i + 2}, $#{i + 3}::timestamp, $#{i + 4}::timestamp, $#{i + 5}::boolean)"
            ],
          params ++
            [
              val(sr, :id),
              val(sr, :scheduling_type),
              val(sr, :start_date) |> parse_date(timezone, preferred_scheduling_time),
              val(sr, :end_date) |> parse_date(timezone, preferred_scheduling_time),
              val(sr, :manually_scheduled)
            ],
          i + 5
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
