defmodule Oli.Delivery.Sections.Audited.Schedule do
  @moduledoc false
  # The schedule of a section: moved here from `Oli.Delivery.Sections.Scheduling.update/3`,
  # which ran its `UPDATE` without a lock or a before-state, and `clear/1`.
  #
  # Both take the section lock (`FOR NO KEY UPDATE`: it serializes with the other writers of
  # the section's resources without blocking inserts that reference the section, such as a
  # student's first page access), lock and read the affected rows in ID order as the
  # before-state, take the written schedule from the write itself (`RETURNING`), and record one
  # `curriculum_schedule_changed` per section resource whose schedule changed, in one insert.
  # Caches are cleared after the commit, as before.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing.{Changes, Context, EntityId}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections.{Scheduling, Section, SectionCache, SectionResource}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Repo
  alias Oli.Resources.Revision

  def update(%Context{} = context, %Section{} = section, updates, timezone) do
    with false <- Repo.in_transaction?(),
         {:ok, sql, params, ids} <-
           Scheduling.update_statement(updates, timezone, section.preferred_scheduling_time) do
      Repo.transaction(fn ->
        with {:ok, _section} <- Support.lock_section(section.id),
             before = schedule(section.id, :id, ids),
             {:ok, result} <- Repo.query(sql, [section.id | params]),
             :ok <- record(context, section.id, before, written(result, before)) do
          result.num_rows
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> invalidate(section)
    else
      true ->
        {:error, :nested_transaction}

      # Nothing to write: the caches are cleared, as before, and nothing is recorded
      {:ok, :empty} ->
        invalidate({:ok, 0}, section)

      {:error, _reason} = error ->
        error
    end
  end

  def clear(%Context{} = context, %Section{} = section) do
    case Repo.in_transaction?() do
      true ->
        {:error, :nested_transaction}

      false ->
        Repo.transaction(fn ->
          with {:ok, _section} <- Support.lock_section(section.id),
               before = schedule(section.id, :dated, nil),
               {count, rows} <- clear_dates(Map.keys(before)),
               :ok <- record(context, section.id, before, cleared(rows, before)) do
            count
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
        |> invalidate(section)
    end
  end

  defp clear_dates(ids) do
    from(sr in SectionResource,
      where: sr.id in ^ids,
      select: %{
        id: sr.id,
        scheduling_type: sr.scheduling_type,
        start_date: sr.start_date,
        end_date: sr.end_date,
        manually_scheduled: sr.manually_scheduled,
        removed_from_schedule: sr.removed_from_schedule
      }
    )
    |> Repo.update_all(set: [start_date: nil, end_date: nil, removed_from_schedule: false])
  end

  # The cleared schedule returned by the update, completed with the resource and title.
  defp cleared(rows, before) do
    Map.new(rows, fn %{id: id} = row ->
      %{resource_id: resource_id, title: title} = Map.fetch!(before, id)
      {id, row |> Map.delete(:id) |> Map.merge(%{resource_id: resource_id, title: title})}
    end)
  end

  defp invalidate({:ok, _count} = result, section) do
    SectionCache.clear(section.slug)
    DepotCoordinator.clear(SectionResourceDepot.depot_desc(), section.id)
    result
  end

  defp invalidate(error, _section), do: error

  # The schedule the `UPDATE` returned, by ID, loaded into the schedule's types (so it compares
  # with the before-state) and completed with the resource and title, which it does not change.
  defp written(%{columns: columns, rows: rows}, before) do
    Map.new(rows, fn row ->
      %SectionResource{} = written = Repo.load(SectionResource, {columns, row})
      %{resource_id: resource_id, title: title} = Map.fetch!(before, written.id)

      {written.id,
       %{
         resource_id: resource_id,
         title: title,
         scheduling_type: written.scheduling_type,
         start_date: written.start_date,
         end_date: written.end_date,
         manually_scheduled: written.manually_scheduled,
         removed_from_schedule: written.removed_from_schedule
       }}
    end)
  end

  # The schedule of the section's resources with `ids` (`:id`) or with a date (`:dated`), by
  # ID, with the title for the snapshot. The rows are locked in ID order, so the before-state
  # holds until the write and concurrent writers of the same rows lock them in the same order.
  defp schedule(section_id, filter, ids) do
    from(sr in SectionResource,
      left_join: rev in Revision,
      on: rev.id == sr.revision_id,
      where: sr.section_id == ^section_id,
      order_by: sr.id,
      # Only the section resources: the revision is on the nullable side of the join
      lock: "FOR NO KEY UPDATE OF s0",
      select:
        {sr.id,
         %{
           resource_id: sr.resource_id,
           title: coalesce(sr.title, rev.title),
           scheduling_type: sr.scheduling_type,
           start_date: sr.start_date,
           end_date: sr.end_date,
           manually_scheduled: sr.manually_scheduled,
           removed_from_schedule: sr.removed_from_schedule
         }}
    )
    |> schedule_filter(filter, ids)
    |> Repo.all()
    |> Map.new()
  end

  defp schedule_filter(query, :id, ids), do: from(sr in query, where: sr.id in ^ids)

  defp schedule_filter(query, :dated, _ids),
    do: from(sr in query, where: not is_nil(sr.start_date) or not is_nil(sr.end_date))

  defp record(context, section_id, before, after_write) do
    proposals =
      Enum.flat_map(before, fn {id, old} ->
        new = Map.fetch!(after_write, id)

        case Changes.diff(old, new, Fields.gating()) do
          changes when changes == %{} ->
            []

          changes ->
            [
              %{
                event_type: :curriculum_schedule_changed,
                entity:
                  {:section_resource,
                   EntityId.compose(section: section_id, resource: new.resource_id),
                   %{title: new.title}},
                scope: %{section_id: section_id, resource_id: new.resource_id},
                event_key: "schedule:#{new.resource_id}:changed",
                changes: changes
              }
            ]
        end
      end)

    Support.record_many(context, proposals)
  end
end
