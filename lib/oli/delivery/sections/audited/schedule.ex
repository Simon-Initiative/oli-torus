defmodule Oli.Delivery.Sections.Audited.Schedule do
  @moduledoc false
  # The schedule of a section: moved here from `Oli.Delivery.Sections.Scheduling.update/3`,
  # which ran its `UPDATE` without a lock or a before-state, and `clear/1`.
  #
  # Both take the section lock (the one gates, remixes, and publication updates take), read the
  # schedule of the affected section resources before and after the write, and record one
  # `curriculum_schedule_changed` per section resource whose schedule changed, in one insert.
  # Caches are cleared after the commit, as before.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing.{Changes, Context, EntityId}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections.{Scheduling, Section, SectionCache, SectionResource}
  alias Oli.Delivery.Sections.{SectionResourceDepot, SectionResourceMigration}
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Repo
  alias Oli.Resources.Revision

  def update(%Context{} = context, %Section{} = section, updates, timezone) do
    with false <- Repo.in_transaction?(),
         {:ok, sql, params, ids} <-
           Scheduling.update_statement(updates, timezone, section.preferred_scheduling_time) do
      Repo.transaction(fn ->
        SectionResourceMigration.lock_section!(section.id)
        before = schedule(section.id, ids)

        with {:ok, %{num_rows: count}} <- Repo.query(sql, [section.id | params]),
             :ok <- record(context, section.id, before, schedule(section.id, ids)) do
          count
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
          SectionResourceMigration.lock_section!(section.id)

          ids =
            Repo.all(
              from(sr in Scheduling.get_section_resources_with_schedule(%{}, section.id),
                select: sr.id
              )
            )

          before = schedule(section.id, ids)

          {count, _} =
            Repo.update_all(
              from(sr in SectionResource, where: sr.id in ^ids),
              set: [start_date: nil, end_date: nil, removed_from_schedule: false]
            )

          case record(context, section.id, before, schedule(section.id, ids)) do
            :ok -> count
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
        |> invalidate(section)
    end
  end

  defp invalidate({:ok, _count} = result, section) do
    SectionCache.clear(section.slug)
    DepotCoordinator.clear(SectionResourceDepot.depot_desc(), section.id)
    result
  end

  defp invalidate(error, _section), do: error

  # The schedule of the section resources with `ids`, by ID, with the title for the snapshot.
  defp schedule(section_id, ids) do
    from(sr in SectionResource,
      left_join: rev in Revision,
      on: rev.id == sr.revision_id,
      where: sr.section_id == ^section_id and sr.id in ^ids,
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
    |> Repo.all()
    |> Map.new()
  end

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
