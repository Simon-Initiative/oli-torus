defmodule Oli.Delivery.Sections.SectionResourceCopy do
  @moduledoc """
  Field-level copy policy for `SectionResource` rows.

  Content structure, scheduling, assessment configuration and page-level AI
  configuration all live on the same `section_resources` row, so a selective
  copy cannot be expressed by choosing which rows to copy. Every row needed by
  the hierarchy is always copied; this module decides, column by column, whether
  a copied row keeps the source value or is reset.

  ## What "reset" means

  Reset does not mean "the schema default". It means *the value a section created
  fresh from the same publication would have*. For most columns that is the
  schema default, but `max_attempts`, `scoring_strategy_id`, `assessment_mode`,
  `batch_scoring`, `replacement_strategy`, `retake_mode` and `collab_space_config`
  are seeded from the pinned revision by
  `Oli.Delivery.Sections.create_section_resources/3`, so resetting them means
  re-reading the revision. `revision_defaults/2` supplies those values.

  ## Ordering constraint

  `ai_enabled` cannot be given its final value here. `PostProcessing.apply/2`
  calls `SectionResourceMigration.project_current/1`, which overwrites it from
  the pinned revision. Instructor overrides must therefore be re-applied by
  `reapply_ai_overrides/2` as the last write of the copy, after post-processing.
  Rows built here always carry the revision value for that column so the
  pre-migration state is deterministic.

  ## Divergence between copy policies

  `manually_scheduled` is absent from `SectionResource.to_map/1` and so has never
  been carried by product duplication. It is genuine instructor scheduling state
  (`Oli.Delivery.Sections.Updates` preserves it across publication updates), so
  the allowlist policy used by course copy does carry it. The `:inherit_all`
  policy used by product duplication deliberately continues to omit it, keeping
  that long-standing path behaviourally unchanged.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.CopyOptions
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision

  # Columns required to reproduce the hierarchy and the resource/project pinning.
  # These are always copied; they are what makes the destination a snapshot at all.
  @structural_fields [
    :numbering_index,
    :numbering_level,
    :children,
    :contained_page_count,
    :slug,
    :resource_id,
    :project_id,
    :section_id,
    :delivery_policy_id,
    :hidden
  ]

  @schedule_fields [:scheduling_type, :start_date, :end_date, :removed_from_schedule]
  @allowlist_only_schedule_fields [:manually_scheduled]

  @schedule_resets %{
    scheduling_type: :read_by,
    start_date: nil,
    end_date: nil,
    removed_from_schedule: false,
    manually_scheduled: false
  }

  # Assessment columns whose reset value is a fixed default.
  @assessment_static_resets %{
    password: nil,
    late_submit: :allow,
    late_start: :allow,
    time_limit: 0,
    grace_period: 0,
    review_submission: :allow,
    feedback_mode: :allow,
    allow_hints: false,
    explanation_strategy: nil
  }

  # Assessment columns whose reset value comes from the pinned revision.
  @assessment_revision_derived [
    :max_attempts,
    :scoring_strategy_id,
    :assessment_mode,
    :batch_scoring,
    :replacement_strategy,
    :retake_mode
  ]

  # Page-level collaboration space configuration is instructor-owned section
  # settings, and is seeded from the revision on a fresh section.
  @section_settings_revision_derived [:collab_space_config]

  @ai_fields [:ai_enabled]

  @doc """
  Loads the revision-seeded defaults for the given resources pinned to `section_id`.

  Returns a map of `resource_id` to the subset of columns that a fresh section
  would seed from the pinned revision. Call this with the *destination* section
  id, after its publication pins have been created, and with the resource ids the
  copy actually needs - a publication pins the whole project, so an unfiltered
  read would materialise far more rows than the copy touches.
  """
  @spec revision_defaults(integer(), [integer()]) :: %{optional(integer()) => map()}
  def revision_defaults(_section_id, []), do: %{}

  def revision_defaults(section_id, resource_ids) do
    query =
      from(spp in SectionsProjectsPublications,
        join: p in Publication,
        on: p.id == spp.publication_id,
        join: pr in PublishedResource,
        on: pr.publication_id == p.id,
        join: r in Revision,
        on: r.id == pr.revision_id,
        where: spp.section_id == ^section_id,
        where: r.resource_id in ^resource_ids,
        select: %{
          resource_id: r.resource_id,
          max_attempts: r.max_attempts,
          scoring_strategy_id: r.scoring_strategy_id,
          assessment_mode: r.assessment_mode,
          batch_scoring: r.batch_scoring,
          replacement_strategy: r.replacement_strategy,
          retake_mode: r.retake_mode,
          collab_space_config: r.collab_space_config,
          ai_enabled: r.ai_enabled
        }
      )

    query
    |> Repo.all()
    |> Map.new(fn row -> {row.resource_id, row} end)
  end

  @doc """
  Builds the insertable map for one copied section resource.

  `overrides` must carry at least the destination `:section_id`, and `:project_id`
  when the copy remaps projects. `now` is the timestamp stamped on the new row:
  copied rows are new rows, so they never inherit the source's `inserted_at`.
  """
  @spec build_row(%SectionResource{}, map(), CopyOptions.t(), map(), DateTime.t()) :: map()
  def build_row(%SectionResource{} = source, overrides, %CopyOptions{} = options, defaults, now) do
    revision = Map.get(defaults, source.resource_id, %{})

    source
    |> Map.from_struct()
    |> Map.take(@structural_fields)
    |> Map.merge(schedule_values(source, options))
    |> Map.merge(assessment_values(source, revision, options))
    |> Map.merge(section_settings_values(source, revision, options))
    |> Map.merge(ai_values(source, revision))
    |> Map.merge(%{inserted_at: now, updated_at: now})
    |> Map.merge(overrides)
  end

  @doc """
  Re-applies instructor-owned page-level `ai_enabled` overrides after migration.

  `SectionResourceMigration.migrate/1` overwrites `ai_enabled` from the pinned
  revision, so a copied override is lost unless it is written again afterwards.
  `overrides` is a list of `{destination_section_resource_id, ai_enabled}` pairs.

  Returns `{:ok, count}` with the number of rows written.
  """
  @spec reapply_ai_overrides(integer(), [{integer(), boolean() | nil}]) ::
          {:ok, non_neg_integer()}
  def reapply_ai_overrides(_section_id, []), do: {:ok, 0}

  def reapply_ai_overrides(section_id, overrides) do
    count =
      overrides
      |> Enum.group_by(fn {_id, ai_enabled} -> ai_enabled end, fn {id, _} -> id end)
      |> Enum.reduce(0, fn {ai_enabled, ids}, acc ->
        {written, _} =
          from(sr in SectionResource,
            where: sr.section_id == ^section_id and sr.id in ^ids
          )
          |> Repo.update_all(set: [ai_enabled: ai_enabled])

        acc + written
      end)

    {:ok, count}
  end

  defp schedule_policy_fields(%CopyOptions{section_field_policy: :allowlist}),
    do: @allowlist_only_schedule_fields

  defp schedule_policy_fields(%CopyOptions{}), do: []

  defp schedule_values(source, %CopyOptions{} = options) do
    fields = @schedule_fields ++ schedule_policy_fields(options)

    case CopyOptions.selected?(options, :schedule) do
      true -> source |> Map.from_struct() |> Map.take(fields)
      false -> Map.take(@schedule_resets, fields)
    end
  end

  defp assessment_values(source, revision, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :assessment_settings) do
      true ->
        source
        |> Map.from_struct()
        |> Map.take(Map.keys(@assessment_static_resets) ++ @assessment_revision_derived)
        |> Map.put(:feedback_mode, feedback_mode(source, options))
        |> Map.put(:feedback_scheduled_date, feedback_scheduled_date(source, options))

      false ->
        @assessment_static_resets
        |> Map.merge(revision_values(revision, @assessment_revision_derived))
        |> Map.put(:max_attempts, Map.get(revision, :max_attempts) || 0)
        |> Map.put(:feedback_scheduled_date, nil)
    end
  end

  # `feedback_scheduled_date` is both an assessment setting and an absolute date.
  # Copying it when the schedule was deliberately not copied would leave the
  # destination holding a stale date from the source's term, so it follows both
  # groups: it is carried only when assessment settings and schedule are copied.
  # Without that date, scheduled feedback stays hidden until the instructor
  # configures a new release policy rather than becoming invalid or public.
  defp feedback_mode(%{feedback_mode: :scheduled}, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :schedule) do
      true -> :scheduled
      false -> :disallow
    end
  end

  defp feedback_mode(source, _options), do: source.feedback_mode

  defp feedback_scheduled_date(source, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :schedule) do
      true -> source.feedback_scheduled_date
      false -> nil
    end
  end

  defp section_settings_values(source, revision, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :section_settings) do
      true ->
        source |> Map.from_struct() |> Map.take(@section_settings_revision_derived)

      false ->
        revision_values(revision, @section_settings_revision_derived)
    end
  end

  # `ai_enabled` is always inserted with the revision value; the instructor
  # override, when selected, is re-applied by `reapply_ai_overrides/2` after
  # migration overwrites this column. See the module doc.
  defp ai_values(source, revision) do
    Map.new(@ai_fields, fn field ->
      case Map.fetch(revision, field) do
        {:ok, value} -> {field, value}
        :error -> {field, Map.get(source, field)}
      end
    end)
  end

  defp revision_values(revision, fields) do
    Map.new(fields, fn field -> {field, Map.get(revision, field)} end)
  end
end
