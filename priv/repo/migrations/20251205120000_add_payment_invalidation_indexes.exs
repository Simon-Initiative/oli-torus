defmodule Oli.Repo.Migrations.AddPaymentInvalidationIndexes do
  use Ecto.Migration

  @doc """
  Adds composite indexes to optimize payment invalidation queries.

  These indexes support the `invalidate_payments_for_user_section/3` function
  which queries payments by:
  1. (type, pending_section_id, pending_user_id) - for pending payments
  2. (type, enrollment_id, section_id) - for finalized payments

  Using partial indexes for non-invalidated types to reduce index size
  since invalidated payments are never queried.
  """

  def change do
    # Index for finding payments by pending fields (used during payment creation and invalidation)
    # Partial index excludes invalidated payments since they're never queried
    create index(:payments, [:type, :pending_section_id, :pending_user_id],
             where: "type != 'invalidated' AND pending_section_id IS NOT NULL",
             name: :payments_pending_lookup_idx
           )

    # Index for finding payments by enrollment (used during invalidation)
    # Partial index excludes invalidated payments since they're never queried
    create index(:payments, [:type, :enrollment_id, :section_id],
             where: "type != 'invalidated' AND enrollment_id IS NOT NULL",
             name: :payments_enrollment_lookup_idx
           )
  end
end
