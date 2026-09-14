defmodule Oli.Delivery.Sections.RelatedActivitiesProjection do
  @moduledoc """
  Builds `related_activities` from the Revisions pinned to one Section.

  Calculation and persistence are separate so normal lifecycle post-processing
  and depot-driven JIT migration can share the exact projection while choosing
  their own transaction and depot-publication boundaries.
  """

  import Ecto.Query

  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @page_type_id ResourceType.id_for_page()
  @objective_type_id ResourceType.id_for_objective()
  @activity_type_id ResourceType.id_for_activity()

  @spec persist(Section.t(), keyword()) :: {:ok, [SectionResource.t()]} | {:error, term()}
  def persist(%Section{} = section, opts \\ []) do
    updates = calculate(section)

    with :ok <- persist_updates(updates) do
      entries =
        case Keyword.get(opts, :return_entries, true) do
          true -> load_entries(updates)
          false -> []
        end

      {:ok, entries}
    end
  end

  defp load_entries(updates) do
    case Enum.map(updates, & &1.id) do
      [] -> []
      ids -> Repo.all(from(sr in SectionResource, where: sr.id in ^ids))
    end
  end

  @spec calculate(Section.t()) :: [%{id: integer(), related_activities: [integer()]}]
  def calculate(%Section{} = section) do
    records =
      from([rev: rev, sr: sr] in DeliveryResolver.section_resource_revisions(section.slug),
        where:
          rev.deleted == false and
            rev.resource_type_id in ^[@page_type_id, @objective_type_id, @activity_type_id],
        select: %{
          id: sr.id,
          resource_id: rev.resource_id,
          resource_type_id: rev.resource_type_id,
          objectives: rev.objectives,
          activity_refs: rev.activity_refs
        }
      )
      |> Repo.all()

    objective_ids =
      records
      |> Enum.filter(&(&1.resource_type_id == @objective_type_id))
      |> MapSet.new(& &1.resource_id)

    activities_by_objective = activities_by_objective(records, objective_ids)

    records
    |> Enum.flat_map(fn record ->
      cond do
        record.resource_type_id == @objective_type_id ->
          [projection(record.id, Map.get(activities_by_objective, record.resource_id, []))]

        record.resource_type_id == @page_type_id ->
          # Direct page objectives are deliberately ignored; page membership is
          # defined only by activities embedded in the pinned page Revision.
          [projection(record.id, record.activity_refs)]

        true ->
          []
      end
    end)
  end

  defp activities_by_objective(records, objective_ids) do
    records
    |> Enum.filter(&(&1.resource_type_id == @activity_type_id))
    |> Enum.reduce(%{}, fn activity, index ->
      activity.objectives
      |> objective_references()
      |> MapSet.intersection(objective_ids)
      |> Enum.reduce(index, fn objective_id, index ->
        Map.update(index, objective_id, [activity.resource_id], &[activity.resource_id | &1])
      end)
    end)
  end

  defp objective_references(objectives) when is_map(objectives) do
    objectives
    |> Map.values()
    |> Enum.flat_map(fn
      ids when is_list(ids) -> ids
      _other -> []
    end)
    |> MapSet.new()
  end

  defp objective_references(_objectives), do: MapSet.new()

  defp projection(id, activity_ids) do
    %{id: id, related_activities: activity_ids |> List.wrap() |> Enum.uniq() |> Enum.sort()}
  end

  # JSON recordset keeps every value parameterized while still updating the
  # projection in bounded statements, independent of relationship count.
  defp persist_updates([]), do: :ok

  defp persist_updates(updates) do
    updates
    |> Enum.chunk_every(500)
    |> Enum.reduce_while(:ok, fn chunk, :ok ->
      case persist_chunk(chunk) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp persist_chunk(updates) do
    payload =
      Enum.map(updates, fn update ->
        %{"id" => update.id, "related_activities" => update.related_activities}
      end)

    sql = """
    UPDATE section_resources AS sr
    SET related_activities = projected.related_activities,
        updated_at = NOW()
    FROM jsonb_to_recordset($1::jsonb)
      AS projected(id bigint, related_activities bigint[])
    WHERE sr.id = projected.id
    """

    case Repo.query(sql, [payload]) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
