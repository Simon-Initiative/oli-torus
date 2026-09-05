defmodule Oli.Repo.Migrations.NullifyPreviousNextIndexForSuppressedSections do
  use Ecto.Migration

  require Logger

  @moduledoc """
  Forces every section with a non-empty `unnumbered_unit_ids` to rebuild its cached
  `previous_next_index` on next access, so previously-persisted navigation links pick up
  suppression-aware numbering (`"display_numbering"`, added to
  `Oli.Delivery.Hierarchy.build_navigation_link_map/1` in this same release).

  `previous_next_index` is a derived cache, not a source of truth: `PreviousNextIndex.retrieve/2,3`
  already rebuilds it just-in-time whenever the field is `nil`. Setting it to `NULL` here is
  therefore sufficient and self-healing on its own -- there is no `down/0` restoration, because
  the prior cached value cannot be reconstructed and there is no need to: it is only ever a cache.

  The actual batching logic lives in `Oli.Delivery.PreviousNextIndexBackfill`, kept out of this
  migration file so it can be exercised directly in tests without needing `Ecto.Migrator`'s
  migration-runner context. See that module's docs for the batching/keyset-pagination design
  (per https://github.com/fly-apps/safe-ecto-migrations, since this repository has no confirmed
  production row count for `sections`).

  `@disable_ddl_transaction` and `@disable_migration_lock` keep each batch's `UPDATE` outside
  the migration's own transaction/lock, so this doesn't hold a single long-lived lock across
  the whole backfill.
  """

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    total_updated = Oli.Delivery.PreviousNextIndexBackfill.run()

    Logger.info(
      "Nullified previous_next_index for #{total_updated} section(s) with non-empty unnumbered_unit_ids"
    )
  end

  def down do
    :ok
  end
end
