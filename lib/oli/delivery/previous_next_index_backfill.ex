defmodule Oli.Delivery.PreviousNextIndexBackfill do
  @moduledoc """
  Core batching logic for the data migration that nulls out `previous_next_index` for
  sections with a non-empty `unnumbered_unit_ids`, so they rebuild through the
  suppression-aware `Oli.Delivery.Hierarchy.build_navigation_link_map/1` on next access.

  Lives here (rather than directly in the `priv/repo/migrations/*.exs` file) so it can be
  exercised directly in tests without going through `Ecto.Migrator`'s migration-runner
  context, which `Ecto.Migration`'s `execute/1`/`repo/0` helpers depend on. The migration
  file itself is a thin wrapper that just calls `run/1`.

  `previous_next_index` is a derived cache, not a source of truth:
  `Oli.Delivery.PreviousNextIndex.retrieve/2,3` already rebuilds it just-in-time whenever
  the field is `nil`, so nulling it here is sufficient and self-healing -- there is
  deliberately no restoration path for a prior cached value.
  """

  alias Oli.Repo

  @default_batch_size 500
  @default_throttle_ms 50

  @doc """
  Runs the backfill to completion, returning the total number of sections updated.

  Batched with keyset pagination over `sections.id` (not `LIMIT`/`OFFSET`): each page first
  selects a bounded, primary-key-ordered batch of section ids (a fast, indexed range scan
  regardless of how many sections in the table actually match), then applies the real
  `unnumbered_unit_ids`/`previous_next_index` predicate only within that batch -- so a
  single page's cost never depends on how many (or how few) sections in the whole table
  are actually affected.

  ## Options
    - `:batch_size` - number of section ids to select per page (default #{@default_batch_size})
    - `:throttle_ms` - milliseconds to sleep between pages (default #{@default_throttle_ms})
  """
  @spec run(keyword()) :: non_neg_integer()
  def run(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    throttle_ms = Keyword.get(opts, :throttle_ms, @default_throttle_ms)

    run_batches(0, 0, batch_size, throttle_ms)
  end

  defp run_batches(last_id, total_updated, batch_size, throttle_ms) do
    %Postgrex.Result{rows: rows} =
      Repo.query!(
        "SELECT id FROM sections WHERE id > $1 ORDER BY id LIMIT $2",
        [last_id, batch_size]
      )

    case Enum.map(rows, fn [id] -> id end) do
      [] ->
        total_updated

      ids ->
        %Postgrex.Result{num_rows: updated_count} =
          Repo.query!(
            """
            UPDATE sections
            SET previous_next_index = NULL
            WHERE id = ANY($1::bigint[])
              AND array_length(unnumbered_unit_ids, 1) > 0
              AND previous_next_index IS NOT NULL
            """,
            [ids]
          )

        next_last_id = List.last(ids)

        if length(ids) == batch_size do
          Process.sleep(throttle_ms)
        end

        run_batches(next_last_id, total_updated + updated_count, batch_size, throttle_ms)
    end
  end
end
