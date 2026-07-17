defmodule Oli.Authoring.ProjectRepair.Repair do
  @moduledoc """
  Applies lock-aware, deterministic shared-activity repairs.

  Repair never accepts a browser-provided plan. It receives a fresh analysis report
  from the context, locks every source activity and every participant page, reruns
  analysis under those locks, and compares a revision-bearing fingerprint before
  the first write. Each changed page is then one transaction containing all of its
  activity clones and exactly one new page revision.

  Page transactions are intentionally sequential and fail-fast. Earlier commits
  remain valid after a later failure, while the failed page rolls back all clones
  and its page revision. A final analysis report makes partial completion safely
  retryable because already-isolated relationships no longer appear as shared.
  """

  alias Oli.Accounts.Author
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.{ContainerEditor, Utils}

  alias Oli.Authoring.ProjectRepair.{
    Analysis,
    PageSummary,
    RepairFailure,
    RepairResult,
    Report
  }

  import Ecto.Query, warn: false

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.{PageContent, ResourceType, Revision}

  @lock_ttl_seconds 10 * 60

  @typedoc "A lock target kind and resource id in deterministic acquisition order."
  @type lock_target :: {:activity | :page, pos_integer()}

  @typedoc "A lock acquired by this repair invocation, including its ownership stamp."
  @type acquired_lock :: %{target: lock_target(), stamp: NaiveDateTime.t()}

  @typedoc "Invocation-owned locks keyed by target for constant-time refresh lookup."
  @type acquired_locks :: %{lock_target() => acquired_lock()}

  @typedoc "Compact repair work for one non-keeper page."
  @type page_work :: %{
          page: PageSummary.t(),
          source_activity_ids: MapSet.t(pos_integer())
        }

  @typedoc "A content-free plan derived from one fresh report."
  @type plan :: %{
          fingerprint: list(),
          lock_targets: [lock_target()],
          page_work: %{pos_integer() => page_work()}
        }

  @typedoc "Validated analysis controls passed through to post-lock/final analysis."
  @type options :: Analysis.options()

  @doc """
  Executes a repair from a fresh report produced for the normalized project.

  Expected operational failures return `{:ok, %RepairResult{status: :failed}}` or
  `:partial`; only context preparation and the initial analysis use top-level error
  tuples. This keeps lock conflicts, stale plans, and page failures renderable by a
  thin LiveView without exposing raw exceptions or authored content.
  """
  @spec repair(Project.t(), Publication.t(), Author.t(), options(), Report.t()) ::
          {:ok, RepairResult.t()}
  def repair(
        %Project{} = project,
        %Publication{} = publication,
        %Author{} = actor,
        options,
        %Report{} = report_before_repair
      ) do
    plan = build_plan(report_before_repair)

    case plan.lock_targets do
      [] ->
        # A missing-only or issue-free project is already complete. In particular,
        # no missing id is ever converted into page work or passed to copy logic.
        {:ok,
         %RepairResult{
           status: :completed,
           report_before_repair: report_before_repair,
           report_after_repair: report_before_repair
         }}

      _targets ->
        execute_with_locks(
          project,
          publication,
          actor,
          options,
          report_before_repair,
          plan
        )
    end
  end

  defp build_plan(%Report{} = report) do
    repairable_groups =
      report.shared_activity_references
      |> Enum.filter(& &1.repairable?)
      |> Enum.sort_by(& &1.activity_resource_id)

    fingerprint = repair_fingerprint(repairable_groups)

    {page_work, lock_targets} =
      Enum.reduce(repairable_groups, {%{}, MapSet.new()}, fn group, {work, locks} ->
        pages = Enum.sort_by(group.pages, & &1.resource_id)
        [_keeper | non_keeper_pages] = pages

        locks =
          locks
          |> MapSet.put({:activity, group.activity_resource_id})
          |> then(fn targets ->
            Enum.reduce(pages, targets, fn page, acc ->
              MapSet.put(acc, {:page, page.resource_id})
            end)
          end)

        work =
          Enum.reduce(non_keeper_pages, work, fn page, acc ->
            Map.update(
              acc,
              page.resource_id,
              %{page: page, source_activity_ids: MapSet.new([group.activity_resource_id])},
              fn existing ->
                %{
                  existing
                  | source_activity_ids:
                      MapSet.put(existing.source_activity_ids, group.activity_resource_id)
                }
              end
            )
          end)

        {work, locks}
      end)

    %{
      fingerprint: fingerprint,
      page_work: page_work,
      lock_targets: Enum.sort_by(lock_targets, &lock_sort_key/1)
    }
  end

  # Fingerprints include every source id and participant page revision. Membership
  # changes, page edits, newly Adaptive pages, or newly missing source activities
  # therefore invalidate the plan before any mutation begins.
  defp repair_fingerprint(repairable_groups) do
    Enum.map(repairable_groups, fn group ->
      pages =
        group.pages
        |> Enum.sort_by(& &1.resource_id)
        |> Enum.map(&{&1.resource_id, &1.revision_id})

      {group.activity_resource_id, pages}
    end)
  end

  defp lock_sort_key({:activity, resource_id}), do: {0, resource_id}
  defp lock_sort_key({:page, resource_id}), do: {1, resource_id}

  defp execute_with_locks(project, publication, actor, options, before_report, plan) do
    case acquire_locks(project, publication, actor, plan.lock_targets) do
      {:ok, acquired_locks} ->
        outcome =
          try do
            run_after_lock_acquisition_hook(options)
            execute_locked(project, publication, actor, options, plan, acquired_locks)
          rescue
            # Repair must never leak exceptions, changesets, activity/page content,
            # or lock-holder details through its public result contract.
            _exception -> failed_outcome(unexpected_failure(), acquired_locks)
          catch
            _kind, _reason -> failed_outcome(unexpected_failure(), acquired_locks)
          end

        warnings = release_locks(project, publication, actor, outcome.acquired_locks)

        finalize_result(
          project,
          publication,
          options,
          before_report,
          outcome,
          warnings
        )

      {:error, failure, acquired_locks} ->
        warnings = release_locks(project, publication, actor, acquired_locks)

        finalize_result(
          project,
          publication,
          options,
          before_report,
          failed_outcome(failure, acquired_locks),
          warnings
        )
    end
  end

  defp acquire_locks(project, publication, actor, lock_targets) do
    stamp = lock_stamp()
    stale_cutoff = NaiveDateTime.add(stamp, -@lock_ttl_seconds, :second)
    stale_cutoff_datetime = DateTime.from_naive!(stale_cutoff, "Etc/UTC")
    resource_ids = Enum.map(lock_targets, fn {_kind, resource_id} -> resource_id end)

    # Acquisition is all-or-none. We first lock the mapping rows with `FOR UPDATE`
    # and validate every target before writing any lock fields. That avoids the
    # partial-update trap where one target is stamped and a later conflict causes
    # the invocation to fail while still owning a leaked lock.
    result =
      try do
        Repo.transaction(fn ->
          mappings =
            lockable_mappings_query(publication.id, resource_ids)
            |> lock("FOR UPDATE")
            |> Repo.all()

          mapping_by_resource_id = Map.new(mappings, &{&1.resource_id, &1})

          case unavailable_lock_target(
                 lock_targets,
                 mapping_by_resource_id,
                 stale_cutoff,
                 stale_cutoff_datetime
               ) do
            nil ->
              case stamp_lock_targets(publication.id, resource_ids, actor.id, stamp) do
                {updated_count, _updated} when updated_count == length(lock_targets) ->
                  :ok

                _other ->
                  Repo.rollback({:error, lock_update_failure(List.first(lock_targets))})
              end

            failed_target ->
              Repo.rollback({:error, lock_failure(failed_target)})
          end
        end)
      rescue
        _exception -> :lock_update_failed
      end

    case result do
      {:ok, :ok} ->
        acquired_locks =
          acquired_locks_from_targets(project, publication, actor, lock_targets, stamp)

        {:ok, acquired_locks}

      :lock_update_failed ->
        {:error, lock_update_failure(List.first(lock_targets)), %{}}

      {:error, {:error, %RepairFailure{} = failure}} ->
        {:error, failure, %{}}
    end
  end

  defp acquired_locks_from_targets(project, publication, actor, lock_targets, stamp) do
    Enum.reduce(lock_targets, %{}, fn target, acquired ->
      {_kind, resource_id} = target
      Broadcaster.broadcast_lock_acquired(project.slug, publication.id, resource_id, actor.id)
      Map.put(acquired, target, %{target: target, stamp: stamp})
    end)
  end

  defp lockable_mappings_query(publication_id, resource_ids) do
    from(mapping in PublishedResource,
      where:
        mapping.publication_id == ^publication_id and
          mapping.resource_id in ^resource_ids,
      select: mapping
    )
  end

  defp unavailable_lock_target(
         lock_targets,
         mapping_by_resource_id,
         stale_cutoff,
         stale_cutoff_datetime
       ) do
    Enum.find(lock_targets, fn {_kind, resource_id} ->
      case Map.fetch(mapping_by_resource_id, resource_id) do
        {:ok, mapping} -> not lock_available?(mapping, stale_cutoff, stale_cutoff_datetime)
        :error -> true
      end
    end)
  end

  defp lock_available?(%{locked_by_id: nil}, _stale_cutoff, _stale_cutoff_datetime), do: true

  defp lock_available?(
         %{lock_updated_at: lock_updated_at},
         stale_cutoff,
         _stale_cutoff_datetime
       )
       when not is_nil(lock_updated_at) do
    NaiveDateTime.compare(lock_updated_at, stale_cutoff) == :lt
  end

  defp lock_available?(%{updated_at: updated_at}, _stale_cutoff, stale_cutoff_datetime) do
    DateTime.compare(updated_at, stale_cutoff_datetime) == :lt
  end

  defp stamp_lock_targets(publication_id, resource_ids, actor_id, stamp) do
    from(mapping in PublishedResource,
      where:
        mapping.publication_id == ^publication_id and
          mapping.resource_id in ^resource_ids
    )
    |> Repo.update_all(set: [locked_by_id: actor_id, lock_updated_at: stamp])
  end

  defp execute_locked(project, publication, actor, options, plan, acquired_locks) do
    case Analysis.analyze(project, publication, options) do
      {:ok, locked_report} ->
        locked_plan = build_plan(locked_report)

        case locked_plan.fingerprint == plan.fingerprint do
          true -> repair_pages(project, publication, actor, plan, acquired_locks)
          false -> failed_outcome(stale_failure(), acquired_locks)
        end

      {:error, {:invalid_page_content, page_resource_id}} ->
        failed_outcome(invalid_page_failure(page_resource_id), acquired_locks)
    end
  end

  defp repair_pages(project, publication, actor, plan, acquired_locks) do
    plan.page_work
    |> Enum.sort_by(fn {page_resource_id, _work} -> page_resource_id end)
    |> Enum.reduce_while(empty_outcome(acquired_locks), fn {_page_resource_id, work}, outcome ->
      # Refresh only the locks needed for the next page transaction. The complete
      # participant set stays locked, but refreshing every lock before every page
      # would scale as changed_pages * total_locks for large repair batches.
      refresh_targets = refresh_targets_for_page(work)

      case refresh_locks(project, publication, actor, refresh_targets, outcome.acquired_locks) do
        {:ok, refreshed_locks} ->
          outcome = %{outcome | acquired_locks: refreshed_locks}

          case repair_page(project, actor, work) do
            {:ok, %{revision: revision, cloned_activity_count: clone_count}} ->
              # PubSub must observe only committed page revisions. Activity copying
              # remains inside the transaction and the page broadcast happens here.
              Broadcaster.broadcast_revision(revision, project.slug)

              {:cont,
               %{
                 outcome
                 | updated_page_count: outcome.updated_page_count + 1,
                   cloned_activity_count: outcome.cloned_activity_count + clone_count
               }}

            {:error, %RepairFailure{} = failure} ->
              {:halt, add_failure(outcome, failure)}
          end

        {:error, failure, refreshed_locks} ->
          {:halt, add_failure(%{outcome | acquired_locks: refreshed_locks}, failure)}
      end
    end)
  end

  defp refresh_targets_for_page(%{page: page, source_activity_ids: source_activity_ids}) do
    source_activity_ids
    |> Enum.map(&{:activity, &1})
    |> Kernel.++([{:page, page.resource_id}])
    |> Enum.sort_by(&lock_sort_key/1)
  end

  defp refresh_locks(project, publication, actor, lock_targets, acquired_locks) do
    Enum.reduce_while(lock_targets, {:ok, acquired_locks}, fn target, {:ok, locks} ->
      case Map.fetch(locks, target) do
        :error ->
          {:halt, {:error, lock_failure(target), locks}}

        {:ok, acquired_lock} ->
          case refresh_repair_lock(project, publication, actor, acquired_lock) do
            {:ok, refreshed_lock} ->
              {:cont, {:ok, Map.put(locks, target, refreshed_lock)}}

            {:error, %RepairFailure{} = failure} ->
              {:halt, {:error, failure, locks}}
          end
      end
    end)
  end

  defp refresh_repair_lock(project, publication, actor, %{target: target, stamp: old_stamp}) do
    {_kind, resource_id} = target
    new_stamp = lock_stamp()

    result =
      try do
        from(mapping in PublishedResource,
          where:
            mapping.publication_id == ^publication.id and
              mapping.resource_id == ^resource_id and
              mapping.locked_by_id == ^actor.id and
              mapping.lock_updated_at == ^old_stamp
        )
        |> Repo.update_all(set: [lock_updated_at: new_stamp])
      rescue
        _exception -> :lock_update_failed
      end

    case result do
      {1, _updated} ->
        Broadcaster.broadcast_lock_acquired(project.slug, publication.id, resource_id, actor.id)
        {:ok, %{target: target, stamp: new_stamp}}

      :lock_update_failed ->
        {:error, lock_update_failure(target)}

      _other ->
        {:error, lock_failure(target)}
    end
  end

  defp repair_page(project, actor, %{page: planned_page} = work) do
    transaction_result =
      Repo.transaction(fn ->
        with {:ok, current_page} <- validate_current_page(project.slug, planned_page),
             {:ok, copies} <-
               clone_sources(project.slug, actor, work.source_activity_ids, planned_page),
             {:ok, rewritten_content} <- rewrite_page(current_page.content, copies, planned_page),
             activity_refs <-
               rewritten_content
               |> Utils.activity_references()
               |> Enum.sort(),
             {:ok, updated_page} <-
               ChangeTracker.track_revision(project.slug, current_page, %{
                 content: rewritten_content,
                 activity_refs: activity_refs,
                 author_id: actor.id
               }) do
          %{revision: updated_page, cloned_activity_count: map_size(copies)}
        else
          {:error, %RepairFailure{} = failure} -> Repo.rollback(failure)
          _other -> Repo.rollback(page_update_failure(planned_page.resource_id))
        end
      end)

    case transaction_result do
      {:ok, result} -> {:ok, result}
      {:error, %RepairFailure{} = failure} -> {:error, failure}
      {:error, _reason} -> {:error, page_update_failure(planned_page.resource_id)}
    end
  rescue
    _exception -> {:error, page_update_failure(planned_page.resource_id)}
  catch
    _kind, _reason -> {:error, page_update_failure(planned_page.resource_id)}
  end

  defp validate_current_page(project_slug, %PageSummary{} = planned_page) do
    case AuthoringResolver.from_resource_id(project_slug, planned_page.resource_id) do
      %Revision{
        id: revision_id,
        resource_type_id: resource_type_id,
        deleted: false,
        resource_scope: :project,
        content: content
      } = revision
      when revision_id == planned_page.revision_id ->
        case resource_type_id == ResourceType.id_for_page() and Analysis.basic_page?(content) do
          true -> {:ok, revision}
          false -> {:error, invalid_page_failure(planned_page.resource_id)}
        end

      _other ->
        {:error, stale_failure(planned_page.resource_id)}
    end
  end

  defp clone_sources(project_slug, actor, source_activity_ids, planned_page) do
    sorted_source_activity_ids = Enum.sort(source_activity_ids)

    source_revisions =
      project_slug
      |> AuthoringResolver.from_resource_id(sorted_source_activity_ids)
      |> List.wrap()
      |> Map.new(&{&1.resource_id, &1})

    sorted_source_activity_ids
    |> Enum.reduce_while({:ok, %{}}, fn source_activity_id, {:ok, copies} ->
      # `deep_copy_activity_revision/4` is the pre-resolved form of the existing
      # tested duplication implementation. Resolving the source revisions once per
      # page avoids resolver queries per clone while preserving `ContainerEditor`
      # activity-create semantics.
      source_reference = %{
        "id" => "project-repair-source-#{source_activity_id}",
        "type" => "activity-reference",
        "activity_id" => source_activity_id,
        "children" => []
      }

      result =
        try do
          case Map.fetch(source_revisions, source_activity_id) do
            {:ok, source_revision} ->
              ContainerEditor.deep_copy_activity_revision(
                source_reference,
                project_slug,
                actor,
                source_revision
              )

            :error ->
              {:error, :copy_failed}
          end
        rescue
          _exception -> {:error, :copy_failed}
        end

      case result do
        {:ok, %{"activity_id" => new_activity_id}} when is_integer(new_activity_id) ->
          {:cont, {:ok, Map.put(copies, source_activity_id, new_activity_id)}}

        _other ->
          {:halt, {:error, activity_copy_failure(planned_page.resource_id, source_activity_id)}}
      end
    end)
  end

  defp rewrite_page(content, copies, planned_page) do
    try do
      rewritten =
        PageContent.map(content, fn
          %{"type" => "activity-reference", "activity_id" => source_id} = node ->
            case Map.fetch(copies, source_id) do
              {:ok, new_activity_id} -> Map.put(node, "activity_id", new_activity_id)
              :error -> node
            end

          node ->
            node
        end)

      {:ok, rewritten}
    rescue
      _exception -> {:error, invalid_page_failure(planned_page.resource_id)}
    end
  end

  defp release_locks(project, publication, actor, acquired_locks) do
    # Release runs in reverse deterministic lock order. Every release is attempted
    # even if an earlier release fails, and each update still matches the repair
    # ownership stamp so another same-admin session cannot be released.
    acquired_locks =
      acquired_locks
      |> Map.values()
      |> Enum.sort_by(fn %{target: target} -> lock_sort_key(target) end, :desc)

    case Enum.reduce(acquired_locks, false, fn %{target: {_kind, resource_id}, stamp: stamp},
                                               failed? ->
           result =
             try do
               from(mapping in PublishedResource,
                 where:
                   mapping.publication_id == ^publication.id and
                     mapping.resource_id == ^resource_id and
                     mapping.locked_by_id == ^actor.id and
                     mapping.lock_updated_at == ^stamp
               )
               |> Repo.update_all(set: [locked_by_id: nil, lock_updated_at: nil])
             rescue
               _exception -> {0, nil}
             end

           case result do
             {1, _updated} ->
               Broadcaster.broadcast_lock_released(project.slug, publication.id, resource_id)
               failed?

             _other ->
               true
           end
         end) do
      true -> [:lock_release_failed]
      false -> []
    end
  end

  defp finalize_result(project, publication, options, before_report, outcome, warnings) do
    {after_report, outcome} =
      case outcome.updated_page_count do
        0 ->
          # If no page committed, the caller's before-report is still the best
          # after-report and avoids a second full project scan on ordinary lock or
          # stale-plan failures.
          {before_report, outcome}

        _updated_pages ->
          case Analysis.analyze(project, publication, options) do
            {:ok, report} ->
              {report, outcome}

            {:error, {:invalid_page_content, page_resource_id}} ->
              # A concurrent malformed unrelated page can prevent final reporting
              # even though participant-page locks protected committed repairs.
              # Preserve a content-free failure and the last complete report as a
              # safe fallback.
              {before_report, add_failure(outcome, invalid_page_failure(page_resource_id))}
          end
      end

    {:ok,
     %RepairResult{
       status: outcome_status(outcome),
       report_before_repair: before_report,
       report_after_repair: after_report,
       cloned_activity_count: outcome.cloned_activity_count,
       updated_page_count: outcome.updated_page_count,
       failures: Enum.reverse(outcome.failures),
       warnings: warnings
     }}
  end

  defp empty_outcome(acquired_locks) do
    %{
      cloned_activity_count: 0,
      updated_page_count: 0,
      failures: [],
      acquired_locks: acquired_locks
    }
  end

  defp failed_outcome(failure, acquired_locks),
    do: add_failure(empty_outcome(acquired_locks), failure)

  defp add_failure(outcome, failure),
    do: %{outcome | failures: [failure | outcome.failures]}

  defp outcome_status(%{failures: []}), do: :completed
  defp outcome_status(%{updated_page_count: count}) when count > 0, do: :partial
  defp outcome_status(_outcome), do: :failed

  defp lock_failure({kind, resource_id}) do
    identifiers = failure_identifiers(kind, resource_id)
    struct!(RepairFailure, [stage: :lock, reason: :lock_not_acquired] ++ identifiers)
  end

  defp lock_update_failure({kind, resource_id}) do
    identifiers = failure_identifiers(kind, resource_id)
    struct!(RepairFailure, [stage: :lock, reason: :lock_update_failed] ++ identifiers)
  end

  defp stale_failure(page_resource_id \\ nil) do
    %RepairFailure{
      stage: :stale_plan,
      reason: :stale_project_state,
      page_resource_id: page_resource_id
    }
  end

  defp invalid_page_failure(page_resource_id) do
    %RepairFailure{
      stage: :page_update,
      reason: :invalid_page_content,
      page_resource_id: page_resource_id
    }
  end

  defp activity_copy_failure(page_resource_id, activity_resource_id) do
    %RepairFailure{
      stage: :activity_copy,
      reason: :activity_copy_failed,
      page_resource_id: page_resource_id,
      activity_resource_id: activity_resource_id
    }
  end

  defp page_update_failure(page_resource_id) do
    %RepairFailure{
      stage: :page_update,
      reason: :page_update_failed,
      page_resource_id: page_resource_id
    }
  end

  defp unexpected_failure do
    %RepairFailure{stage: :cleanup, reason: :unexpected_error}
  end

  defp failure_identifiers(:activity, resource_id),
    do: [activity_resource_id: resource_id]

  defp failure_identifiers(:page, resource_id), do: [page_resource_id: resource_id]

  defp lock_stamp do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:microsecond)
  end

  defp run_after_lock_acquisition_hook(%{after_lock_acquisition: hook}) when is_function(hook, 0),
    do: hook.()

  defp run_after_lock_acquisition_hook(_options), do: :ok
end
