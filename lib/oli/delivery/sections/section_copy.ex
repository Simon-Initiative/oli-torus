defmodule Oli.Delivery.Sections.SectionCopy do
  @moduledoc """
  Creates an independent snapshot of an existing section.

  This is the engine behind both product duplication and course copy. It creates
  a new section row, duplicates the source's publication pins and section
  resources, rewires the copied hierarchy onto the new section-resource ids, and
  copies instructor configuration selected by the given `CopyOptions`.

  ## Independence

  The destination is independent of the source once this returns:

    * The destination is a new section row with a new slug and context id.
    * Every copied section resource is a new row with a new id, and copied
      `children` arrays are rewired onto those new ids.
    * Publication pins are duplicated as destination-owned rows.
    * Shared authoring resources and revisions are safe to share because
      publications are immutable, so the destination stays pinned to the
      snapshot it was created from.
    * No source-section foreign key is stored. `blueprint_id` is copied from the
      source's own `blueprint_id` (including `nil`); the source is never recorded
      as the destination's blueprint, and no parent/child relationship is created.

  ## Learner data

  No learner-owned record is read or written. Enrollments, resource accesses,
  attempts, grades, submissions, discussion posts, analytics, student consent,
  awarded certificates, student-specific assessment exceptions and
  student-specific gating exceptions all live in tables this module never
  touches. Gate duplication is restricted to conditions with a nil `parent_id`,
  which is what makes it skip student exceptions.

  ## Consistency

  The whole copy runs in one transaction, and the source section row is locked
  with `SectionResourceMigration.lock_section!/1` before anything is read. That
  is the lock protocol the section lifecycle write paths already honour, so it
  keeps concurrent edits to the source out of the middle of a copy without
  requiring `REPEATABLE READ` and the transaction-retry machinery that isolation
  level would demand of every caller.

  ## Step ordering

  `PostProcessing.apply/2` calls `SectionResourceMigration.project_current/1`,
  which overwrites revision-derived section-resource columns, `ai_enabled`
  among them. Instructor AI overrides are therefore re-applied as the very last
  write of the copy. See `Oli.Delivery.Sections.SectionResourceCopy`.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Gating
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.CopyOptions
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceCopy
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Repo

  # Gate condition types that store absolute dates, and so follow the :schedule
  # group rather than the :content group. See Gating.duplicate_gates/3.
  @schedule_condition_types [:schedule]
  @content_condition_types [:always_open, :started, :finished, :progress]

  # Section columns that are always generated fresh for the destination, whatever
  # the source holds. Identity, LMS integration state, payment state, derived
  # caches and lifecycle markers all belong to the destination alone.
  @system_defaults %{
    type: :enrollable,
    status: :active,
    visibility: :global,
    analytics_version: :v2,
    open_and_free: false,
    root_section_resource_id: nil,
    invite_token: nil,
    passcode: nil,
    lti_1p3_deployment_id: nil,
    institution_id: nil,
    delivery_policy_id: nil,
    grade_passback_enabled: false,
    line_items_service_url: nil,
    nrps_enabled: false,
    nrps_context_memberships_url: nil,
    resource_gating_index: %{},
    previous_next_index: nil,
    apply_major_updates: false,
    requires_payment: false,
    amount: nil,
    payment_options: :direct_and_deferred,
    pay_by_institution: false,
    has_grace_period: true,
    grace_period_days: nil,
    grace_period_strategy: :relative_to_section,
    contains_discussions: false,
    contains_explorations: false,
    contains_deliberate_practice: false,
    certificate_enabled: false,
    certificate: nil,
    required_survey_resource_id: nil,
    registration_open: false,
    requires_enrollment: false,
    skip_email_verification: false,
    start_date: nil,
    end_date: nil,
    timezone: nil,
    class_modality: :never,
    class_days: [],
    course_section_number: nil,
    description: nil,
    cover_image: nil,
    brand_id: nil,
    customizations: nil,
    display_curriculum_item_numbering: true,
    unnumbered_unit_ids: [],
    welcome_title: %{},
    encouraging_subtitle: nil,
    agenda: true,
    assistant_enabled: false,
    triggers_enabled: false,
    page_prompt_template: nil,
    instructor_recommendations_enabled: true,
    instructor_recommendation_prompt_template: nil
  }

  @section_settings_fields [
    :description,
    :display_curriculum_item_numbering,
    :unnumbered_unit_ids,
    :cover_image,
    :brand_id,
    :welcome_title,
    :encouraging_subtitle,
    :agenda
  ]

  @ai_settings_fields [
    :assistant_enabled,
    :triggers_enabled,
    :page_prompt_template,
    :instructor_recommendations_enabled,
    :instructor_recommendation_prompt_template
  ]

  @doc """
  Copies `source` into a new section.

  `destination_attrs` carries the identity and context the destination owns:
  title, course section number, dates entered during setup, institution and LTI
  deployment, context id, and registration behaviour. It is merged last and so
  always wins over anything the copy policy produced.

  Returns `{:ok, section}` or `{:error, reason}`. Every step participates in one
  transaction, so a failure at any point leaves no partial section behind.
  """
  @spec copy(%Section{}, map(), CopyOptions.t()) :: {:ok, %Section{}} | {:error, term()}
  def copy(%Section{} = source, destination_attrs, %CopyOptions{} = options) do
    started_at = System.monotonic_time()

    Repo.transaction(fn ->
      with {:ok, source} <- lock_source(source),
           {:ok, destination} <- create_destination(source, destination_attrs, options),
           {:ok, pin_count} <- copy_publication_pins(source, destination, options),
           {:ok, resources} <- copy_section_resources(source, destination, options),
           {:ok, destination} <-
             Sections.update_section(destination, %{
               root_section_resource_id: resources.root.id
             }),
           {:ok, exclusion_count} <-
             InstructorCustomizations.duplicate_section_exclusions(source, destination),
           {:ok, gate_count} <- copy_gates(source, destination, options),
           {:ok, destination} <-
             maybe_copy_gating_index(source, destination, options, gate_count),
           {:ok, destination} <- PostProcessing.apply_result(destination, :all),
           # Must be the last write of the copy. Post-processing runs
           # `SectionResourceMigration.project_current/1`, which rewrites
           # `ai_enabled` from the pinned revision, so an overlay applied any
           # earlier than this is silently undone.
           {:ok, _reapplied} <-
             SectionResourceCopy.reapply_ai_overrides(destination.id, resources.ai_overrides) do
        {destination,
         %{
           section_resources: resources.count,
           publication_pins: pin_count,
           activity_exclusions: exclusion_count,
           gates: gate_count
         }}
      else
        {:error, e} -> Repo.rollback(e)
      end
    end)
    |> emit_telemetry(started_at, options)
  end

  # Counts and duration only. Titles, learner identifiers, prompts and content
  # are deliberately excluded, and so are section ids - provenance belongs in the
  # audit event, not in metrics.
  defp emit_telemetry({:ok, {destination, counts}}, started_at, %CopyOptions{} = options) do
    :telemetry.execute(
      [:oli, :delivery, :section_copy],
      Map.put(counts, :duration, System.monotonic_time() - started_at),
      %{
        status: :ok,
        source_kind: options.source_kind,
        section_field_policy: options.section_field_policy,
        groups: CopyOptions.to_audit_list(options)
      }
    )

    {:ok, destination}
  end

  defp emit_telemetry({:error, reason} = result, started_at, %CopyOptions{} = options) do
    :telemetry.execute(
      [:oli, :delivery, :section_copy],
      %{duration: System.monotonic_time() - started_at},
      %{
        status: :error,
        source_kind: options.source_kind,
        section_field_policy: options.section_field_policy,
        groups: CopyOptions.to_audit_list(options),
        reason: telemetry_reason(reason)
      }
    )

    result
  end

  defp telemetry_reason(%Ecto.Changeset{}), do: :changeset
  defp telemetry_reason({reason, _details}) when is_atom(reason), do: reason
  defp telemetry_reason(reason) when is_atom(reason), do: reason
  defp telemetry_reason(_reason), do: :unknown

  # Serializes this copy against concurrent lifecycle writes to the source, so
  # the section row, its pins, its resources, its exclusions and its gates are
  # all read from one consistent state of the source. This is the same lock the
  # section lifecycle write paths already take, which is why it needs no new
  # protocol from them - and why `REPEATABLE READ`, which would demand
  # serialization-failure retries from every caller, is not used here.
  #
  # The row read under the lock replaces the caller's struct for the rest of the
  # copy, so the copy always reflects committed state rather than whatever the
  # caller happened to be holding.
  defp lock_source(%Section{id: id}) do
    {:ok, SectionResourceMigration.lock_section!(id)}
  end

  # ---------------------------------------------------------------------------
  # Destination section row
  # ---------------------------------------------------------------------------

  # Historical product-duplication behaviour: the destination starts from the
  # full source struct. Retained unchanged so product duplication, product-to-
  # section creation and project cloning are unaffected by this extraction.
  # New callers should use the :allowlist policy instead - see CopyOptions.
  defp create_destination(
         %Section{} = source,
         destination_attrs,
         %CopyOptions{section_field_policy: :inherit_all}
       ) do
    params =
      Map.merge(
        %{
          type: :blueprint,
          status: :active,
          base_project_id: source.base_project_id,
          open_and_free: false,
          context_id: UUID.uuid4(),
          start_date: nil,
          end_date: nil,
          brand_id: source.brand_id,
          title: source.title <> " Copy",
          invite_token: nil,
          passcode: nil,
          blueprint_id: nil,
          lti_1p3_deployment_id: nil,
          institution_id: nil,
          delivery_policy_id: nil,
          customizations: embed_to_map(source.customizations),
          contains_explorations: source.contains_explorations,
          contains_deliberate_practice: source.contains_deliberate_practice,
          cover_image: source.cover_image,
          skip_email_verification: source.skip_email_verification,
          registration_open: source.registration_open,
          requires_enrollment: source.requires_enrollment,
          certificate: certificate_attrs(source),
          assistant_enabled: source.assistant_enabled,
          triggers_enabled: source.triggers_enabled,
          page_prompt_template: source.page_prompt_template,
          instructor_recommendations_enabled: source.instructor_recommendations_enabled,
          instructor_recommendation_prompt_template:
            source.instructor_recommendation_prompt_template,
          contains_discussions: source.contains_discussions,
          required_survey_resource_id: source.required_survey_resource_id
        },
        normalize_keys(destination_attrs)
      )
      |> Map.put(:learning_model_version, source.learning_model_version)

    Map.from_struct(source)
    |> Map.merge(params)
    |> Map.drop([:id, :slug])
    # The destination's root resource does not exist yet. Inheriting the source's
    # pointer inserts a row referencing another section's resource, corrected only
    # by a later update; start it empty instead.
    |> Map.put(:root_section_resource_id, nil)
    |> Sections.create_section_from_source(source)
  end

  # Course-copy behaviour: the destination is built from system defaults, plus
  # only the groups explicitly selected, plus destination-owned attributes. A
  # column added to the sections schema after this is written is not copied
  # until a group claims it.
  defp create_destination(
         %Section{} = source,
         destination_attrs,
         %CopyOptions{section_field_policy: :allowlist} = options
       ) do
    @system_defaults
    |> Map.merge(lineage(source))
    |> Map.merge(copied_section_settings(source, options))
    |> Map.merge(copied_ai_settings(source, options))
    |> Map.merge(%{context_id: UUID.uuid4()})
    |> Map.merge(normalize_keys(destination_attrs))
    |> Sections.create_section_from_source(source)
  end

  # The destination inherits the source's lineage, not the source itself.
  #
  # `blueprint_id` is deliberately the source's own `blueprint_id`, including
  # `nil`: if the source was seeded from a product, both sections refer to that
  # same product; if it was not, neither does. Note that this is not inert
  # bookkeeping - `Oli.Delivery.Sections.Updates` branches on `blueprint_id` when
  # applying a major publication update, deferring to the product's
  # `apply_major_updates` flag. A copy of a product-seeded section therefore
  # inherits that update behaviour, exactly as the source has it.
  defp lineage(%Section{} = source) do
    %{
      base_project_id: source.base_project_id,
      blueprint_id: source.blueprint_id
    }
  end

  defp copied_section_settings(%Section{} = source, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :section_settings) do
      false ->
        %{}

      true ->
        source
        |> Map.from_struct()
        |> Map.take(@section_settings_fields)
        |> Map.merge(%{
          customizations: embed_to_map(source.customizations),
          certificate_enabled: source.certificate_enabled,
          certificate: certificate_attrs(source)
        })
    end
  end

  defp copied_ai_settings(%Section{} = source, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :ai_settings) do
      false -> %{}
      true -> source |> Map.from_struct() |> Map.take(@ai_settings_fields)
    end
  end

  # `certificate_enabled` and the certificate row move together: a section with
  # the flag set and no certificate record is not a valid state.
  #
  # `:section_id` stays in the attrs even though the destination owns a different
  # one - `Certificate.changeset/2` requires it, and `cast_assoc` overwrites the
  # owner key on insert. `:id` and the timestamps are dropped so the new row is
  # unambiguously new. `granted_certificate` is learner data and is never loaded.
  defp certificate_attrs(%Section{} = source) do
    case Repo.preload(source, :certificate).certificate do
      nil ->
        nil

      certificate ->
        certificate
        |> Map.from_struct()
        |> Map.drop([:id, :inserted_at, :updated_at, :section, :granted_certificate, :__meta__])
    end
  end

  defp embed_to_map(nil), do: nil
  defp embed_to_map(embed), do: Map.from_struct(embed)

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} -> {key, value}
    end)
  end

  # ---------------------------------------------------------------------------
  # Publication pins
  # ---------------------------------------------------------------------------

  defp copy_publication_pins(%Section{id: source_id}, %Section{} = destination, %CopyOptions{
         project_remap: project_remap
       }) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      from(spp in SectionsProjectsPublications,
        where: spp.section_id == ^source_id,
        select: spp
      )
      |> Repo.all()
      |> Enum.map(fn spp ->
        {project_id, publication_id} =
          remap_pin(spp.project_id, spp.publication_id, destination, project_remap)

        %{
          section_id: destination.id,
          project_id: project_id,
          publication_id: publication_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    with :ok <- validate_publication_pins(rows),
         {count, _} <-
           Repo.insert_all(SectionsProjectsPublications, rows,
             on_conflict: :nothing,
             conflict_target: [:section_id, :project_id]
           ),
         true <- count == length(rows) do
      {:ok, count}
    else
      false -> {:error, :publication_pin_copy_incomplete}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_publication_pins(rows) do
    Enum.reduce_while(rows, :ok, fn attrs, :ok ->
      changeset =
        %SectionsProjectsPublications{}
        |> SectionsProjectsPublications.changeset(attrs)

      case changeset.valid? do
        true -> {:cont, :ok}
        false -> {:halt, {:error, changeset}}
      end
    end)
  end

  # When a product is duplicated as part of cloning its project, pins that point
  # at the original project are re-pointed at the clone's project and publication.
  defp remap_pin(project_id, publication_id, %Section{} = destination, {remap_from, remap_to}) do
    case project_id == remap_from do
      true -> {destination.base_project_id, remap_to}
      false -> {project_id, publication_id}
    end
  end

  defp remap_pin(project_id, publication_id, _destination, _project_remap),
    do: {project_id, publication_id}

  defp remap_project_id(project_id, %Section{} = destination, {remap_from, _remap_to}) do
    case project_id == remap_from do
      true -> destination.base_project_id
      false -> project_id
    end
  end

  defp remap_project_id(project_id, _destination, _project_remap), do: project_id

  # ---------------------------------------------------------------------------
  # Section resources
  # ---------------------------------------------------------------------------

  defp copy_section_resources(
         %Section{id: source_id, root_section_resource_id: root_id},
         %Section{} = destination,
         %CopyOptions{} = options
       ) do
    source_resources =
      from(sr in SectionResource, where: sr.section_id == ^source_id, select: sr)
      |> Repo.all()

    resource_ids = source_resources |> Enum.map(& &1.resource_id) |> Enum.uniq()
    revision_defaults = SectionResourceCopy.revision_defaults(destination.id, resource_ids)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(source_resources, fn sr ->
        overrides = %{
          section_id: destination.id,
          project_id: remap_project_id(sr.project_id, destination, options.project_remap)
        }

        SectionResourceCopy.build_row(sr, overrides, options, revision_defaults, now)
      end)

    {_count, inserted} = Sections.bulk_create_section_resource(rows, returning: true)

    id_map =
      Enum.zip(source_resources, inserted)
      |> Map.new(fn {source, copy} -> {source.id, copy.id} end)

    # The inserted rows still carry the source's children ids. Rewire them onto
    # the destination's own section resource ids; anything unresolvable (nil or
    # an unknown id from historical data corruption) is dropped.
    rewired =
      Enum.map(inserted, fn sr ->
        children =
          (sr.children || [])
          |> Enum.map(&Map.get(id_map, &1))
          |> Enum.reject(&is_nil/1)

        sr |> SectionResource.to_map() |> Map.put(:children, children)
      end)

    {_count, updated} = Sections.bulk_update_section_resource(rewired, returning: true)

    case Enum.find(updated, &(Map.get(id_map, root_id) == &1.id)) do
      nil ->
        {:error, {:root_section_resource_not_copied, root_id}}

      root ->
        {:ok,
         %{
           root: root,
           count: length(rows),
           ai_overrides: ai_overrides(source_resources, inserted, revision_defaults, options)
         }}
    end
  end

  # An instructor AI override is a page whose `ai_enabled` differs from the value
  # its pinned revision carries. Only those need re-applying after migration;
  # everything else already matches what migration writes.
  defp ai_overrides(source_resources, inserted, revision_defaults, %CopyOptions{} = options) do
    case CopyOptions.selected?(options, :ai_settings) do
      false ->
        []

      true ->
        Enum.zip(source_resources, inserted)
        |> Enum.filter(fn {source, _copy} ->
          revision = Map.get(revision_defaults, source.resource_id, %{})
          source.ai_enabled != Map.get(revision, :ai_enabled)
        end)
        |> Enum.map(fn {source, copy} -> {copy.id, source.ai_enabled} end)
    end
  end

  # ---------------------------------------------------------------------------
  # Gates
  # ---------------------------------------------------------------------------

  defp copy_gates(%Section{} = source, %Section{} = destination, %CopyOptions{} = options) do
    Gating.duplicate_gates(source, destination, gate_condition_types(options))
  end

  defp gate_condition_types(%CopyOptions{section_field_policy: :inherit_all}), do: :all

  defp gate_condition_types(%CopyOptions{} = options) do
    schedule =
      case CopyOptions.selected?(options, :schedule) do
        true -> @schedule_condition_types
        false -> []
      end

    @content_condition_types ++ schedule
  end

  # `resource_gating_index` maps an authoring resource id to the gated ancestor
  # resource ids above it. Both sides are project-scoped rather than
  # section-scoped, so the source's index is already correct for the destination.
  #
  # It must be copied whenever gates are copied: `Gating.blocked_by/3`
  # short-circuits to `[]` for any resource missing from the index, so a section
  # holding gating conditions with an empty index has gates that are never
  # evaluated. Regenerating the index here is not an option - that path reads the
  # depot, which is not warm during section creation.
  defp maybe_copy_gating_index(
         _source,
         %Section{} = destination,
         %CopyOptions{section_field_policy: :inherit_all},
         _gate_count
       ),
       do: {:ok, destination}

  defp maybe_copy_gating_index(_source, %Section{} = destination, _options, 0),
    do: {:ok, destination}

  defp maybe_copy_gating_index(%Section{} = source, %Section{} = destination, _options, _count) do
    Sections.update_section(destination, %{resource_gating_index: source.resource_gating_index})
  end
end
