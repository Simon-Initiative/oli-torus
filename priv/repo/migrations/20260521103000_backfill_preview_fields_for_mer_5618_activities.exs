defmodule Oli.Repo.Migrations.BackfillPreviewFieldsForMer5618Activities do
  use Ecto.Migration

  @moduledoc """
  Backfills `preview_script` and `preview_element` for the activity registrations
  that gain first-class preview support in MER-5618.

  Why this exists:

  - The preceding migration only adds the new nullable columns and indexes.
  - Existing rows in `activity_registrations` will otherwise keep `NULL` preview
    metadata until local activities are re-registered.
  - That is acceptable for brand new databases created through seeds, because the
    registrar will populate the fields during bootstrap, but it is not sufficient
    for already-running environments that apply the migration in place.

  Why authoring/delivery did not need a similar backfill:

  - `authoring_*` and `delivery_*` were part of the original
    `activity_registrations` table definition.
  - Their values were populated by the initial local activity registration flow
    when the table and registrar were first introduced, rather than being added
    later to already-populated rows.

  Why this migration is explicit instead of reading manifests:

  - Safe Ecto migration guidance favors schema and data migrations that are
    deterministic and independent from the current application code or frontend
    filesystem.
  - This backfill is intentionally narrow: it only updates the seven Jira-scoped
    activities that are migrated to preview in MER-5618.

  Future note:

  - If additional already-registered activities gain first-class preview support
    in later tickets, they should receive a similar focused backfill for their
    `preview_*` metadata unless an operational re-registration step is guaranteed
    for all target environments.
  """

  def up do
    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_multiple_choice_preview.js',
        preview_element = 'oli-multiple-choice-preview'
    WHERE slug = 'oli_multiple_choice'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_check_all_that_apply_preview.js',
        preview_element = 'oli-check-all-that-apply-preview'
    WHERE slug = 'oli_check_all_that_apply'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_multi_input_preview.js',
        preview_element = 'oli-multi-input-preview'
    WHERE slug = 'oli_multi_input'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_image_hotspot_preview.js',
        preview_element = 'oli-image-hotspot-preview'
    WHERE slug = 'oli_image_hotspot'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_likert_preview.js',
        preview_element = 'oli-likert-preview'
    WHERE slug = 'oli_likert'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_ordering_preview.js',
        preview_element = 'oli-ordering-preview'
    WHERE slug = 'oli_ordering'
    """)

    execute("""
    UPDATE activity_registrations
    SET preview_script = 'oli_directed_discussion_preview.js',
        preview_element = 'oli-directed-discussion-preview'
    WHERE slug = 'oli_directed_discussion'
    """)
  end

  def down do
    execute("""
    UPDATE activity_registrations
    SET preview_script = NULL,
        preview_element = NULL
    WHERE slug IN (
      'oli_multiple_choice',
      'oli_check_all_that_apply',
      'oli_multi_input',
      'oli_image_hotspot',
      'oli_likert',
      'oli_ordering',
      'oli_directed_discussion'
    )
    """)
  end
end
