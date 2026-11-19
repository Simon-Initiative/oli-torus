defmodule Oli.Delivery.Settings.Audited.AssessmentSettings do
  @moduledoc false
  # Section-level settings of assessments: one setting from the settings table, and the bulk
  # apply that copies one assessment's settings to the others.
  #
  # Moved here:
  #   * the write of `Oli.Delivery.Settings.AssessmentSettings.update/5` (its Multi, with the
  #     auto-submit adjustment), whose validation stays there as `prepare_update/5`; the
  #     `settings_changes` history rows it wrote are replaced by the event;
  #   * the bulk apply of `OliWeb.Sections.AssessmentSettings.SettingsTable`
  #     (`"confirm_bulk_apply"`), which ran three updates and a history insert without a
  #     transaction.
  #
  # Each assessment that changed records one `assessment_settings_changed` with the persisted
  # fields that changed; the before-state is the locked section resource row.

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Auditing.{Changes, Command, Context}
  alias Oli.Delivery.Sections.{Section, SectionResource, SectionResourceDepot}
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Settings.AutoSubmitCustodian
  alias Oli.Delivery.Settings.Audited.Support
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Publishing.DeliveryResolver

  # One setting

  def update(%Context{} = context, %Section{} = section, resource_id, attrs, opts) do
    with {:ok, actor} <- Support.actor(context),
         {:ok, assessment, changes} <-
           AssessmentSettings.prepare_update(section, actor, resource_id, attrs, opts),
         {:ok, section_resource} <- write(context, section, assessment, changes) do
      SectionResourceDepot.update_section_resource(section_resource)

      {:ok,
       %{
         assessment:
           AssessmentSettings.refresh_assessment(section, resource_id, assessment, changes),
         applied_changes: changes
       }}
    end
  end

  defp write(context, section, assessment, changes) do
    resource_id = assessment.resource_id

    Command.run(:section_resource, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes -> lock(section.id, [resource_id]) end)
      |> Multi.run(:section_resource, fn repo, %{before: [before]} ->
        with {:ok, _count} <- maybe_cancel_auto_submit(section.id, resource_id, changes) do
          before |> SectionResource.changeset(changes) |> repo.update()
        end
      end)
      |> Multi.run(:auto_submit, fn _repo, _changes ->
        maybe_adjust_auto_submit(section.id, assessment, changes)
      end)
      |> Multi.run(:event, fn _repo, %{before: [before], section_resource: updated} ->
        record(context, section, [{before, updated}])
      end)
    end)
  end

  # Allowing late submissions cancels the scheduled auto-submits of the assessment.
  defp maybe_cancel_auto_submit(section_id, resource_id, %{late_submit: :allow}),
    do: AutoSubmitCustodian.cancel(section_id, resource_id, nil)

  defp maybe_cancel_auto_submit(_section_id, _resource_id, _changes), do: {:ok, 0}

  # A new end date moves the scheduled auto-submits when late submissions are disallowed.
  defp maybe_adjust_auto_submit(section_id, assessment, %{end_date: new_end_date}) do
    case assessment.late_submit == :disallow and not is_nil(assessment.end_date) do
      true ->
        AutoSubmitCustodian.adjust(
          section_id,
          assessment.resource_id,
          assessment.end_date,
          new_end_date,
          nil
        )

      false ->
        {:ok, 0}
    end
  end

  defp maybe_adjust_auto_submit(_section_id, _assessment, _changes), do: {:ok, 0}

  # Bulk apply

  def bulk_apply(%Context{} = context, %Section{} = section, base_resource_id) do
    assessments =
      AssessmentSettings.get_assessments(
        section,
        AssessmentSettings.get_student_exceptions(section.id)
      )

    with {:ok, base} <- find_base(assessments, base_resource_id),
         {:ok, changed} <- bulk_write(context, section, base, assessments) do
      section.id
      |> section_resources(Enum.map(assessments, & &1.resource_id))
      |> then(&DepotCoordinator.update_all(SectionResourceDepot.depot_desc(), &1))

      {:ok, changed}
    end
  end

  defp find_base(assessments, base_resource_id) do
    case Enum.find(assessments, &(&1.resource_id == base_resource_id)) do
      nil -> {:error, :not_found}
      base -> {:ok, base}
    end
  end

  # Writes what the settings table wrote: the common settings on every other graded page, the
  # replacement strategy on the basic (non-adaptive) ones, and the scoring mode on the basic
  # ones no student has started. Auto-submits are not adjusted, as before.
  defp bulk_write(context, section, base, assessments) do
    targets = Enum.reject(assessments, &(&1.resource_id == base.resource_id))
    target_ids = Enum.map(targets, & &1.resource_id)
    basic_ids = targets |> Enum.reject(& &1.is_adaptive) |> Enum.map(& &1.resource_id)

    Command.run(:changed, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes -> lock(section.id, target_ids) end)
      |> Multi.run(:started, fn _repo, _changes ->
        {:ok, AssessmentSettings.student_started_resource_ids(section.id, basic_ids)}
      end)
      |> Multi.run(:written, fn repo, %{started: started} ->
        unstarted_ids = Enum.reject(basic_ids, &MapSet.member?(started, &1))
        {:ok, bulk_update(repo, section, base, basic_ids, unstarted_ids)}
      end)
      |> Multi.run(:after, fn _repo, _changes ->
        {:ok, section_resources(section.id, target_ids)}
      end)
      |> Multi.run(:changed, fn _repo, %{before: before, after: after_rows} ->
        after_by_id = Map.new(after_rows, &{&1.id, &1})
        pairs = Enum.map(before, &{&1, Map.fetch!(after_by_id, &1.id)})

        with {:ok, _} <- record(context, section, pairs) do
          {:ok, Enum.count(pairs, fn {old, new} -> diff(old, new) != %{} end)}
        end
      end)
    end)
  end

  defp bulk_update(repo, section, base, basic_ids, unstarted_ids) do
    feedback_date =
      case base.feedback_mode do
        :scheduled -> [feedback_scheduled_date: base.feedback_scheduled_date]
        _mode -> []
      end

    common =
      feedback_date ++
        [
          max_attempts: base.max_attempts,
          retake_mode: base.retake_mode,
          assessment_mode: base.assessment_mode,
          late_submit: base.late_submit,
          late_start: base.late_start,
          time_limit: base.time_limit,
          grace_period: base.grace_period,
          scoring_strategy_id: base.scoring_strategy_id,
          review_submission: base.review_submission,
          feedback_mode: base.feedback_mode,
          password: base.password,
          allow_hints: base.allow_hints
        ]

    from([sr, _s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section.slug),
      where:
        rev.resource_type_id == 1 and rev.graded == true and
          sr.resource_id != ^base.resource_id,
      select: sr
    )
    |> repo.update_all(set: common)

    from(sr in SectionResource,
      where: sr.section_id == ^section.id and sr.resource_id in ^basic_ids
    )
    |> repo.update_all(set: [replacement_strategy: base.replacement_strategy])

    from(sr in SectionResource,
      where: sr.section_id == ^section.id and sr.resource_id in ^unstarted_ids
    )
    |> repo.update_all(set: [batch_scoring: base.batch_scoring])

    :ok
  end

  # Reads and events

  # Locks the section resources of `resource_ids` in ID order, so concurrent writers of the
  # same rows lock them in the same order, and returns them as the before-state.
  defp lock(section_id, resource_ids) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id in ^resource_ids,
      order_by: sr.id,
      lock: "FOR NO KEY UPDATE"
    )
    |> Oli.Repo.all()
    |> case do
      [] when resource_ids != [] -> {:error, :not_found}
      rows -> {:ok, rows}
    end
  end

  defp section_resources(section_id, resource_ids) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id in ^resource_ids,
      order_by: sr.id
    )
    |> Oli.Repo.all()
  end

  defp record(context, section, pairs) do
    proposals =
      Enum.map(pairs, fn {before, updated} ->
        %{
          event_type: :assessment_settings_changed,
          entity: {:resource, updated.resource_id, updated},
          scope: %{section_id: section.id, resource_id: updated.resource_id},
          event_key: "assessment:#{updated.resource_id}:settings_changed",
          changes: diff(before, updated)
        }
      end)

    case Support.record_many(context, proposals) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  defp diff(before, updated), do: Changes.diff(before, updated, Support.assessment_policy())
end
