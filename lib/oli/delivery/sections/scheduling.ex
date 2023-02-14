defmodule Oli.Delivery.Sections.Scheduling do
  @moduledoc """
  Provides the read and write operations for managing the "soft-schedule" for a course section.
  """

  import Ecto.Query, warn: false

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
  def retrieve(%Section{id: section_id}) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

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
          pr.resource_id == sr.resource_id and
          (rev.resource_type_id == ^container_type_id or rev.resource_type_id == ^page_type_id)
      )
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
  def update(%Section{id: section_id}, updates) do
    if is_valid_update?(updates) do
      case build_values_params(updates) do
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

  defp is_valid_update?(updates) do
    keys = ["id", "scheduling_type", "start_date", "end_date", "manually_scheduled"]
    atoms = Enum.map(keys, fn k -> String.to_existing_atom(k) end)

    both = Enum.zip(keys, atoms)

    Enum.all?(updates, fn u ->
      Enum.all?(both, fn {k, a} -> Map.has_key?(u, k) or Map.has_key?(u, a) end)
    end)
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    [y, m, d] =
      String.split(date_str, "-")
      |> Enum.map(fn s -> String.to_integer(s) end)

    {:ok, date} = Date.new(y, m, d)
    date
  end

  defp build_values_params(updates) do
    {values, params, _} =
      Enum.reduce(updates, {[], [], 1}, fn sr, {values, params, i} ->
        {
          values ++
            [
              "($#{i + 1}::bigint, $#{i + 2}, $#{i + 3}::date, $#{i + 4}::date, $#{i + 5}::boolean)"
            ],
          params ++
            [
              val(sr, :id),
              val(sr, :scheduling_type),
              val(sr, :start_date) |> parse_date(),
              val(sr, :end_date) |> parse_date(),
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
