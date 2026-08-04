defmodule Oli.Authoring.ProjectRepairTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import ExUnit.CaptureLog

  @moduletag capture_log: true

  alias Oli.Accounts
  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Authoring.Editing.Utils
  alias Oli.Authoring.Locks
  alias Oli.Authoring.ProjectRepair

  alias Oli.Authoring.ProjectRepair.{
    MissingActivityReference,
    PageSummary,
    RepairFailure,
    RepairResult,
    Report,
    SharedActivityReference,
    Summary
  }

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources
  alias Oli.Resources.{Resource, Revision}

  setup do
    # The standard seed creates a real unpublished project publication and two
    # current Basic pages. Using real authoring mappings here ensures Phase 1
    # project normalization is tested against the same state later phases scan.
    seed = Seeder.base_project_with_resource2()

    system_admin =
      author_fixture(%{system_role_id: SystemRole.role_id().system_admin})

    {:ok, Map.put(seed, :system_admin, system_admin)}
  end

  describe "domain contracts" do
    test "report contracts retain compact page metadata but no page content", %{project: project} do
      page = %PageSummary{
        resource_id: 101,
        revision_id: 201,
        revision_slug: "example-page",
        title: "Example page"
      }

      missing = %MissingActivityReference{activity_resource_id: 301, page: page}

      shared = %SharedActivityReference{
        activity_resource_id: 302,
        pages: [page],
        repairable?: true
      }

      summary = %Summary{missing_activity_reference_count: 1}

      assert summary.repairable_shared_activity_affected_page_count == 0

      report = %Report{
        project_id: project.id,
        project_slug: project.slug,
        missing_activity_references: [missing],
        shared_activity_references: [shared],
        summary: summary
      }

      failure = %RepairFailure{stage: :lock, reason: :lock_not_acquired}

      result = %RepairResult{
        status: :failed,
        report_before_repair: report,
        report_after_repair: report,
        failures: [failure]
      }

      # Reports can remain in LiveView state, so full JSON must never become part
      # of their public shape. The revision id is retained for later stale checks.
      refute Map.has_key?(Map.from_struct(page), :content)
      refute Map.has_key?(Map.from_struct(report), :content)
      assert result.report_before_repair.project_id == project.id
      assert result.failures == [failure]
    end
  end

  describe "authorization and project preparation" do
    test "a system admin analyzes a persisted project", %{
      project: project,
      system_admin: system_admin
    } do
      assert {:ok, %Report{} = report} = ProjectRepair.analyze_project(project, system_admin)
      assert report.project_id == project.id
      assert report.project_slug == project.slug
    end

    test "a system admin receives the same deterministic report from a project slug", %{
      project: project,
      system_admin: system_admin
    } do
      assert {:ok, report} =
               ProjectRepair.analyze_project(project.slug, system_admin,
                 stream_max_rows: 1,
                 resolution_batch_size: 1
               )

      assert report.project_id == project.id
      assert report.scanned_pages_count == 2
      assert report.skipped_adaptive_pages_count == 0
      assert report.missing_activity_references == []
      assert report.shared_activity_references == []
    end

    test "repair uses the same preparation boundary as analysis", %{
      project: project,
      system_admin: system_admin
    } do
      assert {:ok, %RepairResult{status: :completed} = result} =
               ProjectRepair.repair_project(project.slug, system_admin)

      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert result.failures == []
    end

    test "unknown and stale project references fail deterministically", %{
      project: project,
      system_admin: system_admin
    } do
      assert {:error, :project_not_found} =
               ProjectRepair.analyze_project("project-that-does-not-exist", system_admin)

      # Matching both id and slug prevents a hand-built or stale struct from being
      # trusted merely because it contains the slug of a real project.
      stale_project = %{project | id: project.id + 1}

      assert {:error, :project_not_found} =
               ProjectRepair.analyze_project(stale_project, system_admin)
    end

    test "a project without an unpublished publication fails deterministically", %{
      project: project,
      publication: publication,
      system_admin: system_admin
    } do
      {:ok, _published} =
        Publishing.update_publication(publication, %{published: DateTime.utc_now()})

      assert {:error, :working_publication_not_found} =
               ProjectRepair.analyze_project(project, system_admin)

      assert {:error, :working_publication_not_found} =
               ProjectRepair.repair_project(project.slug, system_admin)
    end

    test "non-system-admin and malformed actors are rejected before project probing", %{
      author: author
    } do
      # The intentionally unknown project and malformed options prove authorization
      # is evaluated first: neither lower-priority error may leak to this caller.
      assert {:error, :not_authorized} =
               ProjectRepair.analyze_project("private-project", author,
                 stream_max_rows: 0,
                 unknown: :option
               )

      assert {:error, :not_authorized} =
               ProjectRepair.repair_project("private-project", author,
                 stream_max_rows: 0,
                 unknown: :option
               )

      assert {:error, :not_authorized} =
               ProjectRepair.repair_project("private-project", nil)
    end

    test "authorization uses current persisted role state rather than the caller struct", %{
      project: project,
      system_admin: stale_system_admin
    } do
      {:ok, persisted_author} =
        Accounts.update_author(stale_system_admin, %{
          system_role_id: SystemRole.role_id().author
        })

      refute Accounts.is_system_admin?(persisted_author)
      assert Accounts.is_system_admin?(stale_system_admin)

      # The original struct still carries the system-admin role. Rejection proves
      # the context reloaded the actor before making its authorization decision.
      assert {:error, :not_authorized} =
               ProjectRepair.analyze_project(project, stale_system_admin)

      assert {:error, :not_authorized} =
               ProjectRepair.repair_project(project, stale_system_admin)
    end

    test "a hand-built author with no persisted account is rejected", %{project: project} do
      nonexistent_actor = %Author{
        id: 2_000_000_000,
        system_role_id: SystemRole.role_id().system_admin
      }

      assert {:error, :not_authorized} =
               ProjectRepair.analyze_project(project, nonexistent_actor)

      assert {:error, :not_authorized} =
               ProjectRepair.repair_project(project, nonexistent_actor)
    end

    test "processing options are restricted to positive bounded batch sizes", %{
      project: project,
      system_admin: system_admin
    } do
      assert {:error, {:invalid_options, {:expected_integer_between, :stream_max_rows, 1, 500}}} =
               ProjectRepair.analyze_project(project, system_admin, stream_max_rows: 0)

      assert {:error,
              {:invalid_options, {:expected_integer_between, :resolution_batch_size, 1, 1_000}}} =
               ProjectRepair.analyze_project(project, system_admin, resolution_batch_size: 1_001)

      # The upper bounds themselves remain valid and produce the same read-only
      # report as default options.
      assert {:ok, %Report{scanned_pages_count: 2}} =
               ProjectRepair.analyze_project(project, system_admin,
                 stream_max_rows: 500,
                 resolution_batch_size: 1_000
               )

      assert {:error, {:invalid_options, {:unknown_options, [:unsafe_option]}}} =
               ProjectRepair.analyze_project(project, system_admin, unsafe_option: :infinity)

      assert {:error, {:invalid_options, :expected_keyword_list}} =
               ProjectRepair.analyze_project(project, system_admin, [:not_a_keyword])
    end
  end

  describe "lock-aware deterministic repair" do
    test "missing-only shared references are report-only and create no writes", seed do
      missing_activity_id = missing_activity_resource_id()

      first_page =
        page_fixture(
          seed,
          "First missing-only page",
          activity_reference_content([missing_activity_id])
        )

      second_page =
        page_fixture(
          seed,
          "Second missing-only page",
          activity_reference_content([missing_activity_id])
        )

      before_repair = storage_snapshot(seed)

      assert {:ok, %RepairResult{status: :completed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert result.failures == []
      assert result.warnings == []
      assert result.report_after_repair.summary.missing_activity_reference_count == 2

      assert AuthoringResolver.from_resource_id(seed.project.slug, first_page.resource.id).content ==
               first_page.revision.content

      assert AuthoringResolver.from_resource_id(seed.project.slug, second_page.resource.id).content ==
               second_page.revision.content

      assert storage_snapshot(seed) == before_repair
    end

    test "repairs a shared activity deterministically and preserves missing references", seed do
      source_activity = activity_fixture(seed, "Complete source activity")

      {:ok, source_revision} =
        Resources.update_revision(source_activity.revision, %{
          content: %{"stem" => "source activity content", "custom" => %{"value" => 7}},
          objectives: %{"part-1" => [101, 202]}
        })

      missing_activity_id = missing_activity_resource_id()

      keeper_page =
        page_fixture(
          seed,
          "Lowest-id keeper page",
          activity_reference_content([source_activity.resource.id, missing_activity_id])
        )

      second_page =
        page_fixture(
          seed,
          "Second repaired page",
          activity_reference_content([source_activity.resource.id, missing_activity_id])
        )

      third_page =
        page_fixture(
          seed,
          "Third repaired page",
          activity_reference_content([source_activity.resource.id])
        )

      adaptive_page =
        page_fixture(
          seed,
          "Unchanged Adaptive page",
          activity_reference_content([source_activity.resource.id], true)
        )

      assert {:ok, %RepairResult{status: :completed} = result} =
               ProjectRepair.repair_project(seed.project.slug, seed.system_admin,
                 stream_max_rows: 1,
                 resolution_batch_size: 1
               )

      assert result.cloned_activity_count == 2
      assert result.updated_page_count == 2
      assert result.failures == []
      assert result.warnings == []

      current_keeper = current_revision(seed, keeper_page)
      current_second = current_revision(seed, second_page)
      current_third = current_revision(seed, third_page)
      current_adaptive = current_revision(seed, adaptive_page)

      # Lowest page resource id is the deterministic keeper. Adaptive content is
      # absent from the plan and therefore retains both its revision and source id.
      assert current_keeper.id == keeper_page.revision.id

      assert referenced_activity_ids(current_keeper) ==
               MapSet.new([source_activity.resource.id, missing_activity_id])

      assert current_adaptive.id == adaptive_page.revision.id

      assert referenced_activity_ids(current_adaptive) ==
               MapSet.new([source_activity.resource.id])

      second_ids = referenced_activity_ids(current_second)
      third_ids = referenced_activity_ids(current_third)
      second_clone_id = Enum.find(second_ids, &(&1 != missing_activity_id))
      [third_clone_id] = MapSet.to_list(third_ids)

      refute second_clone_id == source_activity.resource.id
      refute third_clone_id == source_activity.resource.id
      refute second_clone_id == third_clone_id

      for clone_id <- [second_clone_id, third_clone_id] do
        clone = AuthoringResolver.from_resource_id(seed.project.slug, clone_id)
        assert clone.title == source_revision.title
        assert clone.content == source_revision.content
        assert clone.objectives == source_revision.objectives
      end

      # The repair rewrites only `activity_id`; unrelated node fields and missing
      # references survive byte-for-byte in the new page content.
      assert activity_reference_node(current_second, missing_activity_id) ==
               activity_reference_node(second_page.revision, missing_activity_id)

      assert activity_reference_node(current_second, second_clone_id)["customData"] == %{
               "preserve" => 0
             }

      assert current_second.activity_refs == Enum.sort(MapSet.to_list(second_ids))
      assert current_third.activity_refs == Enum.sort(MapSet.to_list(third_ids))

      assert result.report_after_repair.summary.repairable_shared_activity_resource_count == 0
      assert result.report_after_repair.summary.missing_activity_reference_count == 2

      assert_locks_released(seed, [
        source_activity.resource.id,
        keeper_page.resource.id,
        second_page.resource.id,
        third_page.resource.id
      ])

      # AC-022: rerunning is idempotent because repaired relationships no longer
      # produce work, while unresolved references remain report-only.
      assert {:ok, rerun} = ProjectRepair.repair_project(seed.project, seed.system_admin)
      assert rerun.status == :completed
      assert rerun.cloned_activity_count == 0
      assert rerun.updated_page_count == 0
      assert rerun.report_after_repair.summary.missing_activity_reference_count == 2
    end

    test "several shared groups affecting one page create one page revision", seed do
      first_activity = activity_fixture(seed, "First independent source")
      second_activity = activity_fixture(seed, "Second independent source")

      first_keeper =
        page_fixture(
          seed,
          "First group keeper",
          activity_reference_content([first_activity.resource.id])
        )

      second_keeper =
        page_fixture(
          seed,
          "Second group keeper",
          activity_reference_content([second_activity.resource.id])
        )

      shared_non_keeper =
        page_fixture(
          seed,
          "Two-group non-keeper",
          activity_reference_content([
            first_activity.resource.id,
            second_activity.resource.id
          ])
        )

      revision_count_before = Repo.aggregate(Revision, :count, :id)

      assert {:ok, %RepairResult{status: :completed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 2
      assert result.updated_page_count == 1

      current_non_keeper = current_revision(seed, shared_non_keeper)
      assert current_non_keeper.previous_revision_id == shared_non_keeper.revision.id
      assert MapSet.size(referenced_activity_ids(current_non_keeper)) == 2

      # Two activity revisions plus exactly one page revision were added. Keeper
      # pages remain on their original revisions and retain the original sources.
      assert Repo.aggregate(Revision, :count, :id) == revision_count_before + 3
      assert current_revision(seed, first_keeper).id == first_keeper.revision.id
      assert current_revision(seed, second_keeper).id == second_keeper.revision.id
    end

    test "repair derives work from fresh state instead of an earlier preview", seed do
      source_activity = activity_fixture(seed, "Fresh-plan source")

      keeper =
        page_fixture(
          seed,
          "Preview keeper",
          activity_reference_content([source_activity.resource.id])
        )

      second_page =
        page_fixture(
          seed,
          "Preview second page",
          activity_reference_content([source_activity.resource.id])
        )

      assert {:ok, preview} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      assert [preview_group] = preview.shared_activity_references
      assert length(preview_group.pages) == 2

      third_page =
        page_fixture(
          seed,
          "Added after preview",
          activity_reference_content([source_activity.resource.id])
        )

      assert {:ok, %RepairResult{status: :completed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 2
      assert result.updated_page_count == 2
      assert [fresh_group] = result.report_before_repair.shared_activity_references

      assert Enum.map(fresh_group.pages, & &1.resource_id) ==
               [keeper.resource.id, second_page.resource.id, third_page.resource.id]
    end

    test "post-lock project changes abort as stale without repair writes", seed do
      source_activity = activity_fixture(seed, "Stale-plan source")

      keeper_page =
        page_fixture(
          seed,
          "Stale-plan keeper",
          activity_reference_content([source_activity.resource.id])
        )

      changed_page =
        page_fixture(
          seed,
          "Stale-plan changed page",
          activity_reference_content([source_activity.resource.id])
        )

      resource_count_before = Repo.aggregate(Resource, :count, :id)
      revision_count_before = Repo.aggregate(Revision, :count, :id)

      # The hook runs after every participant lock is owned by this repair but
      # before the mandatory post-lock analysis. Updating the page body in place
      # creates the interleaving AC-016 cares about without adding extra revisions
      # that would obscure whether repair itself wrote anything.
      hook = fn ->
        {:ok, _changed_revision} =
          Resources.update_revision(changed_page.revision, %{
            content: %{"model" => []},
            activity_refs: []
          })

        send(self(), :stale_hook_ran)
      end

      assert {:ok, %RepairResult{status: :failed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin,
                 after_lock_acquisition: hook
               )

      assert_received :stale_hook_ran
      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert [%RepairFailure{stage: :stale_plan, reason: :stale_project_state}] = result.failures
      assert Repo.aggregate(Resource, :count, :id) == resource_count_before
      assert Repo.aggregate(Revision, :count, :id) == revision_count_before

      assert_locks_released(seed, [
        source_activity.resource.id,
        keeper_page.resource.id,
        changed_page.resource.id
      ])
    end

    test "a participant lock conflict causes zero repair writes and preserves the holder", seed do
      source_activity = activity_fixture(seed, "Locked source")

      first_page =
        page_fixture(
          seed,
          "Locked group first",
          activity_reference_content([source_activity.resource.id])
        )

      second_page =
        page_fixture(
          seed,
          "Locked group second",
          activity_reference_content([source_activity.resource.id])
        )

      {:acquired} =
        Locks.acquire(
          seed.project.slug,
          seed.publication.id,
          second_page.resource.id,
          seed.author2.id
        )

      resource_count_before = Repo.aggregate(Resource, :count, :id)
      revision_count_before = Repo.aggregate(Revision, :count, :id)

      assert {:ok, %RepairResult{status: :failed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert [%RepairFailure{stage: :lock, reason: :lock_not_acquired}] = result.failures
      assert Repo.aggregate(Resource, :count, :id) == resource_count_before
      assert Repo.aggregate(Revision, :count, :id) == revision_count_before
      assert current_revision(seed, first_page).id == first_page.revision.id
      assert current_revision(seed, second_page).id == second_page.revision.id

      assert_locks_released(seed, [source_activity.resource.id, first_page.resource.id])

      locked_page_mapping =
        Publishing.get_published_resource!(seed.publication.id, second_page.resource.id)

      assert locked_page_mapping.locked_by_id == seed.author2.id

      assert {:ok} =
               Locks.release(
                 seed.project.slug,
                 seed.publication.id,
                 second_page.resource.id,
                 seed.author2.id
               )
    end

    test "a lock already held by the invoking admin is not adopted or released", seed do
      source_activity = activity_fixture(seed, "Same-admin locked source")

      page_fixture(
        seed,
        "Same-admin first page",
        activity_reference_content([source_activity.resource.id])
      )

      page_fixture(
        seed,
        "Same-admin second page",
        activity_reference_content([source_activity.resource.id])
      )

      {:acquired} =
        Locks.acquire(
          seed.project.slug,
          seed.publication.id,
          source_activity.resource.id,
          seed.system_admin.id
        )

      assert {:ok, %RepairResult{status: :failed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert [%RepairFailure{stage: :lock, reason: :lock_not_acquired}] = result.failures

      mapping =
        Publishing.get_published_resource!(seed.publication.id, source_activity.resource.id)

      assert mapping.locked_by_id == seed.system_admin.id

      assert {:ok} =
               Locks.release(
                 seed.project.slug,
                 seed.publication.id,
                 source_activity.resource.id,
                 seed.system_admin.id
               )
    end

    test "a failed page rolls back its clones after earlier pages commit and is retryable",
         seed do
      valid_activity = activity_fixture(seed, "Valid partial source")
      invalid_activity = activity_fixture(seed, "Invalid partial source")
      original_activity_type_id = invalid_activity.revision.activity_type_id

      {:ok, _invalid_revision} =
        Resources.update_revision(invalid_activity.revision, %{activity_type_id: nil})

      keeper =
        page_fixture(
          seed,
          "Partial keeper",
          activity_reference_content([valid_activity.resource.id, invalid_activity.resource.id])
        )

      successful_page =
        page_fixture(
          seed,
          "Partial successful page",
          activity_reference_content([valid_activity.resource.id])
        )

      failed_page =
        page_fixture(
          seed,
          "Partial failed page",
          activity_reference_content([valid_activity.resource.id, invalid_activity.resource.id])
        )

      resource_count_before = Repo.aggregate(Resource, :count, :id)
      revision_count_before = Repo.aggregate(Revision, :count, :id)

      assert {:ok, %RepairResult{status: :partial} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 1
      assert result.updated_page_count == 1

      assert [failure] = result.failures
      assert failure.stage == :activity_copy
      assert failure.reason == :activity_copy_failed
      assert failure.page_resource_id == failed_page.resource.id
      assert failure.activity_resource_id == invalid_activity.resource.id

      assert current_revision(seed, keeper).id == keeper.revision.id
      refute current_revision(seed, successful_page).id == successful_page.revision.id
      assert current_revision(seed, failed_page).id == failed_page.revision.id

      # The failed page cloned the lower-id valid source before the invalid source
      # failed. Its outer page transaction rolls that clone back, so only the one
      # clone and page revision from the earlier committed page remain.
      assert Repo.aggregate(Resource, :count, :id) == resource_count_before + 1
      assert Repo.aggregate(Revision, :count, :id) == revision_count_before + 2

      assert result.report_after_repair.summary.repairable_shared_activity_resource_count == 2

      assert_locks_released(seed, [
        valid_activity.resource.id,
        invalid_activity.resource.id,
        keeper.resource.id,
        successful_page.resource.id,
        failed_page.resource.id
      ])

      current_invalid =
        AuthoringResolver.from_resource_id(seed.project.slug, invalid_activity.resource.id)

      {:ok, _fixed_revision} =
        Resources.update_revision(current_invalid, %{activity_type_id: original_activity_type_id})

      assert {:ok, %RepairResult{status: :completed} = retry_result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert retry_result.cloned_activity_count == 2
      assert retry_result.updated_page_count == 1

      assert retry_result.report_after_repair.summary.repairable_shared_activity_resource_count ==
               0
    end

    test "a page revision failure rolls back cloned activities and is retryable", seed do
      source_activity = activity_fixture(seed, "Page-update failure source")

      keeper_page =
        page_fixture(
          seed,
          "Page-update keeper",
          activity_reference_content([source_activity.resource.id])
        )

      failed_page =
        page_fixture(
          seed,
          "Page-update failed page",
          activity_reference_content([source_activity.resource.id])
        )

      # `ChangeTracker.track_revision/3` creates a new revision from the current
      # page revision. A nil title makes that new revision invalid after the clone
      # has been created inside the transaction, proving the clone rolls back with
      # the page update failure.
      from(revision in Revision,
        where: revision.id == ^failed_page.revision.id
      )
      |> Repo.update_all(set: [title: nil])

      resource_count_before = Repo.aggregate(Resource, :count, :id)
      revision_count_before = Repo.aggregate(Revision, :count, :id)

      assert {:ok, %RepairResult{status: :failed} = result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert result.cloned_activity_count == 0
      assert result.updated_page_count == 0
      assert [%RepairFailure{stage: :page_update, reason: :page_update_failed}] = result.failures
      assert Repo.aggregate(Resource, :count, :id) == resource_count_before
      assert Repo.aggregate(Revision, :count, :id) == revision_count_before
      assert current_revision(seed, failed_page).id == failed_page.revision.id

      assert_locks_released(seed, [
        source_activity.resource.id,
        keeper_page.resource.id,
        failed_page.resource.id
      ])

      from(revision in Revision,
        where: revision.id == ^failed_page.revision.id
      )
      |> Repo.update_all(set: [title: failed_page.revision.title])

      assert {:ok, %RepairResult{status: :completed} = retry_result} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert retry_result.cloned_activity_count == 1
      assert retry_result.updated_page_count == 1

      assert retry_result.report_after_repair.summary.repairable_shared_activity_resource_count ==
               0
    end
  end

  describe "operational instrumentation" do
    test "analysis emits bounded telemetry and completion logs without authored content", seed do
      handler =
        attach_project_repair_telemetry([[:oli, :authoring, :project_repair, :analysis, :stop]])

      page_fixture(
        seed,
        "Sensitive Page Title",
        %{"model" => []}
      )

      assert {:ok, %Report{} = report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin,
                 stream_max_rows: 1,
                 resolution_batch_size: 1
               )

      assert report.scanned_pages_count == 3

      assert_receive {:telemetry_event, [:oli, :authoring, :project_repair, :analysis, :stop],
                      %{count: 1, duration_ms: duration_ms}, metadata}

      assert is_integer(duration_ms)
      assert metadata.operation == :analysis
      assert metadata.status == :completed
      assert metadata.project_id == seed.project.id
      assert metadata.project_slug == seed.project.slug
      assert metadata.actor_id == seed.system_admin.id
      assert metadata.scanned_pages_count == 3
      assert metadata.stream_max_rows == 1
      assert metadata.resolution_batch_size == 1

      # The operational contract is count-oriented. Page titles and JSON content
      # are intentionally absent from both telemetry metadata and completion logs.
      refute inspect(metadata) =~ "Sensitive Page Title"

      :telemetry.detach(handler)
    end

    test "repair telemetry covers success, stale, lock, partial, and fatal outcomes", seed do
      handler =
        attach_project_repair_telemetry([[:oli, :authoring, :project_repair, :repair, :stop]])

      assert {:ok, %RepairResult{status: :completed}} =
               ProjectRepair.repair_project(seed.project, seed.system_admin)

      assert_repair_telemetry(:completed, nil, nil)

      source_activity = activity_fixture(seed, "Telemetry stale source")

      keeper_page =
        page_fixture(
          seed,
          "Telemetry stale keeper",
          activity_reference_content([source_activity.resource.id])
        )

      stale_page =
        page_fixture(
          seed,
          "Telemetry stale changed",
          activity_reference_content([source_activity.resource.id])
        )

      stale_hook = fn ->
        {:ok, _changed_revision} =
          Resources.update_revision(stale_page.revision, %{
            content: %{"model" => []},
            activity_refs: []
          })
      end

      capture_log(fn ->
        assert {:ok, %RepairResult{status: :failed}} =
                 ProjectRepair.repair_project(seed.project, seed.system_admin,
                   after_lock_acquisition: stale_hook
                 )
      end)

      assert_repair_telemetry(:failed, :stale_plan, :stale_project_state)

      assert_locks_released(seed, [
        source_activity.resource.id,
        keeper_page.resource.id,
        stale_page.resource.id
      ])

      locked_activity = activity_fixture(seed, "Telemetry locked source")

      page_fixture(
        seed,
        "Telemetry lock first",
        activity_reference_content([locked_activity.resource.id])
      )

      locked_page =
        page_fixture(
          seed,
          "Telemetry lock second",
          activity_reference_content([locked_activity.resource.id])
        )

      {:acquired} =
        Locks.acquire(
          seed.project.slug,
          seed.publication.id,
          locked_page.resource.id,
          seed.author2.id
        )

      capture_log(fn ->
        assert {:ok, %RepairResult{status: :failed}} =
                 ProjectRepair.repair_project(seed.project, seed.system_admin)
      end)

      assert_repair_telemetry(:failed, :lock, :lock_not_acquired)

      assert {:ok} =
               Locks.release(
                 seed.project.slug,
                 seed.publication.id,
                 locked_page.resource.id,
                 seed.author2.id
               )

      valid_activity = activity_fixture(seed, "Telemetry partial valid")
      invalid_activity = activity_fixture(seed, "Telemetry partial invalid")

      {:ok, _invalid_revision} =
        Resources.update_revision(invalid_activity.revision, %{activity_type_id: nil})

      page_fixture(
        seed,
        "Telemetry partial keeper",
        activity_reference_content([valid_activity.resource.id, invalid_activity.resource.id])
      )

      page_fixture(
        seed,
        "Telemetry partial success",
        activity_reference_content([valid_activity.resource.id])
      )

      page_fixture(
        seed,
        "Telemetry partial failure",
        activity_reference_content([valid_activity.resource.id, invalid_activity.resource.id])
      )

      capture_log(fn ->
        assert {:ok, %RepairResult{status: :partial}} =
                 ProjectRepair.repair_project(seed.project, seed.system_admin)
      end)

      assert_repair_telemetry(:partial, :activity_copy, :activity_copy_failed)

      malformed_page =
        page_fixture(seed, "Telemetry malformed page", %{
          "model" => [%{"id" => "node-without-required-type"}]
        })

      capture_log(fn ->
        assert {:error, {:invalid_page_content, resource_id}} =
                 ProjectRepair.repair_project(seed.project, seed.system_admin)

        assert resource_id == malformed_page.resource.id
      end)

      assert_repair_telemetry(:failed, :context, :invalid_page_content)

      :telemetry.detach(handler)
    end

    test "telemetry handler failures do not change analysis results", seed do
      handler_id = "project-repair-raising-handler-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :authoring, :project_repair, :analysis, :stop],
        fn _event, _measurements, _metadata, _config -> raise "handler failed" end,
        nil
      )

      assert {:ok, %Report{scanned_pages_count: 2}} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      :telemetry.detach(handler_id)
    end
  end

  describe "streamed read-only analysis" do
    test "a project with reference-free pages returns an empty report without writes", seed do
      before_analysis = storage_snapshot(seed)

      assert {:ok, %Report{} = report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin,
                 stream_max_rows: 1,
                 resolution_batch_size: 1
               )

      # The base project contains two current Basic pages with empty models. A
      # stream fetch size of one exercises multiple cursor fetches without changing
      # the compact result or creating any authoring, delivery, or learner rows.
      assert report.scanned_pages_count == 2
      assert report.skipped_adaptive_pages_count == 0
      assert report.missing_activity_references == []
      assert report.shared_activity_references == []

      assert report.summary == %Summary{
               scanned_pages_count: 2,
               skipped_adaptive_pages_count: 0,
               missing_activity_reference_count: 0,
               missing_activity_affected_page_count: 0,
               repairable_shared_activity_resource_count: 0,
               repairable_shared_activity_affected_page_count: 0,
               non_repairable_shared_missing_activity_resource_count: 0
             }

      assert storage_snapshot(seed) == before_analysis
    end

    test "reports nested missing and shared references for Basic pages only", seed do
      first_activity = activity_fixture(seed, "First shared activity")
      second_activity = activity_fixture(seed, "Second shared activity")
      missing_single_id = missing_activity_resource_id()
      missing_shared_id = missing_activity_resource_id()
      adaptive_only_missing_id = missing_activity_resource_id()

      first_page =
        page_fixture(
          seed,
          "First issue page",
          activity_reference_content([
            first_activity.resource.id,
            first_activity.resource.id,
            second_activity.resource.id,
            missing_single_id
          ])
        )

      second_page =
        page_fixture(
          seed,
          "Second issue page",
          activity_reference_content(
            [first_activity.resource.id, missing_shared_id],
            false
          )
        )

      third_page =
        page_fixture(
          seed,
          "Third issue page",
          activity_reference_content([second_activity.resource.id, missing_shared_id])
        )

      no_reference_page = page_fixture(seed, "No-reference page", %{"model" => []})

      adaptive_page =
        page_fixture(
          seed,
          "Excluded Adaptive page",
          activity_reference_content(
            [first_activity.resource.id, adaptive_only_missing_id],
            true
          )
        )

      before_analysis = storage_snapshot(seed)
      handler_id = "project-repair-resolver-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :resolvers, :authoring],
        fn _event, _measurements, _metadata, test_pid -> send(test_pid, :resolver_batch) end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:ok, report} =
               ProjectRepair.analyze_project(seed.project.slug, seed.system_admin,
                 stream_max_rows: 1,
                 resolution_batch_size: 1
               )

      # Four unique Basic-page activity ids require exactly four one-id resolver
      # batches. The repeated first-page reference and Adaptive-only missing id do
      # not create extra resolver queries, guarding against relationship N+1s.
      for _index <- 1..4, do: assert_receive(:resolver_batch)
      refute_receive :resolver_batch

      assert report.scanned_pages_count == 6
      assert report.skipped_adaptive_pages_count == 1

      assert Enum.map(report.missing_activity_references, fn missing ->
               {missing.page.resource_id, missing.activity_resource_id}
             end) ==
               [
                 {first_page.resource.id, missing_single_id},
                 {second_page.resource.id, missing_shared_id},
                 {third_page.resource.id, missing_shared_id}
               ]

      assert Enum.map(report.missing_activity_references, fn missing ->
               {missing.page.title, missing.page.revision_slug}
             end) ==
               [
                 {first_page.revision.title, first_page.revision.slug},
                 {second_page.revision.title, second_page.revision.slug},
                 {third_page.revision.title, third_page.revision.slug}
               ]

      assert Enum.map(report.shared_activity_references, fn shared ->
               {
                 shared.activity_resource_id,
                 Enum.map(shared.pages, & &1.resource_id),
                 shared.repairable?
               }
             end) ==
               [
                 {first_activity.resource.id, [first_page.resource.id, second_page.resource.id],
                  true},
                 {second_activity.resource.id, [first_page.resource.id, third_page.resource.id],
                  true},
                 {missing_shared_id, [second_page.resource.id, third_page.resource.id], false}
               ]

      assert Enum.map(report.shared_activity_references, fn shared ->
               Enum.map(shared.pages, &{&1.title, &1.revision_slug})
             end) ==
               [
                 [
                   {first_page.revision.title, first_page.revision.slug},
                   {second_page.revision.title, second_page.revision.slug}
                 ],
                 [
                   {first_page.revision.title, first_page.revision.slug},
                   {third_page.revision.title, third_page.revision.slug}
                 ],
                 [
                   {second_page.revision.title, second_page.revision.slug},
                   {third_page.revision.title, third_page.revision.slug}
                 ]
               ]

      assert report.summary == %Summary{
               scanned_pages_count: 6,
               skipped_adaptive_pages_count: 1,
               missing_activity_reference_count: 3,
               missing_activity_affected_page_count: 3,
               repairable_shared_activity_resource_count: 2,
               repairable_shared_activity_affected_page_count: 3,
               non_repairable_shared_missing_activity_resource_count: 1
             }

      # Compact metadata is sufficient for future editor links and stale checks.
      # Full JSON from all five new pages must have become unreachable after each
      # cursor row and must never cross the context boundary.
      expected_reported_page_ids =
        [first_page, second_page, third_page]
        |> Enum.map(& &1.resource.id)
        |> Enum.sort()

      actual_reported_page_ids =
        report.shared_activity_references
        |> Enum.flat_map(& &1.pages)
        |> Enum.map(& &1.resource_id)
        |> Enum.uniq()
        |> Enum.sort()

      assert actual_reported_page_ids == expected_reported_page_ids
      refute adaptive_page.resource.id in actual_reported_page_ids
      refute no_reference_page.resource.id in actual_reported_page_ids

      for shared <- report.shared_activity_references,
          page <- shared.pages do
        refute Map.has_key?(Map.from_struct(page), :content)
      end

      assert storage_snapshot(seed) == before_analysis
    end

    test "excludes deleted and non-project page revisions from the cursor", seed do
      deleted_page = page_fixture(seed, "Deleted page", %{"model" => []})
      blueprint_page = page_fixture(seed, "Blueprint-scoped page", %{"model" => []})

      {:ok, _deleted_revision} =
        Resources.update_revision(deleted_page.revision, %{deleted: true})

      {:ok, _blueprint_revision} =
        Resources.update_revision(blueprint_page.revision, %{resource_scope: :blueprint})

      assert {:ok, report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      assert report.scanned_pages_count == 2
      assert report.skipped_adaptive_pages_count == 0
    end

    test "a reference to a resolvable non-activity resource is never repairable", seed do
      target_page = page_fixture(seed, "Wrong-type target page", %{"model" => []})

      first_referring_page =
        page_fixture(
          seed,
          "First wrong-type reference",
          activity_reference_content([target_page.resource.id])
        )

      second_referring_page =
        page_fixture(
          seed,
          "Second wrong-type reference",
          activity_reference_content([target_page.resource.id])
        )

      assert {:ok, report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      # The generic authoring resolver can resolve the target page, but the repair
      # analyzer's activity-only projection must classify it as missing. This keeps
      # Phase 3 from ever passing a page/container revision to activity-copy code.
      assert Enum.map(report.missing_activity_references, fn missing ->
               {missing.page.resource_id, missing.activity_resource_id}
             end) ==
               [
                 {first_referring_page.resource.id, target_page.resource.id},
                 {second_referring_page.resource.id, target_page.resource.id}
               ]

      assert [shared] = report.shared_activity_references
      assert shared.activity_resource_id == target_page.resource.id
      refute shared.repairable?
    end

    test "a corrupt mapping cannot certify the wrong resource id as an activity", seed do
      target_page = page_fixture(seed, "Corrupt-mapping target page", %{"model" => []})
      unrelated_activity = activity_fixture(seed, "Unrelated mapped activity")

      {:ok, unmapped_activity_revision} =
        Resources.create_revision_from_previous(unrelated_activity.revision, %{})

      target_mapping =
        Repo.get_by!(PublishedResource,
          publication_id: seed.publication.id,
          resource_id: target_page.resource.id
        )

      # Deliberately create a mapping/revision resource mismatch that normal APIs
      # never produce. The activity-only resolver must validate both ids, or this
      # page resource id would be falsely certified by the activity revision type.
      target_mapping
      |> Ecto.Changeset.change(revision_id: unmapped_activity_revision.id)
      |> Repo.update!()

      referring_page =
        page_fixture(
          seed,
          "Corrupt-mapping referring page",
          activity_reference_content([target_page.resource.id])
        )

      assert {:ok, report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      assert [missing] = report.missing_activity_references
      assert missing.page.resource_id == referring_page.resource.id
      assert missing.activity_resource_id == target_page.resource.id
      assert report.shared_activity_references == []
    end

    test "a corrupt page mapping cannot scan a mismatched revision", seed do
      target_page = page_fixture(seed, "Corrupt page mapping target", %{"model" => []})
      unrelated_page = page_fixture(seed, "Corrupt page mapping unrelated", %{"model" => []})

      {:ok, unmapped_unrelated_revision} =
        Resources.create_revision_from_previous(unrelated_page.revision, %{})

      target_mapping =
        Repo.get_by!(PublishedResource,
          publication_id: seed.publication.id,
          resource_id: target_page.resource.id
        )

      # A working-publication mapping must not be trusted unless its selected
      # revision belongs to the same resource id. Without that join predicate this
      # would scan a revision that is not actually current for the mapped resource.
      target_mapping
      |> Ecto.Changeset.change(revision_id: unmapped_unrelated_revision.id)
      |> Repo.update!()

      assert {:ok, report} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      assert report.scanned_pages_count == 3
      assert report.shared_activity_references == []
      assert report.missing_activity_references == []
    end

    test "fails with the page resource id when established traversal cannot read content", seed do
      malformed_page =
        page_fixture(seed, "Malformed page", %{
          "model" => [%{"id" => "node-without-required-type"}]
        })

      before_analysis = storage_snapshot(seed)

      assert {:error, {:invalid_page_content, resource_id}} =
               ProjectRepair.analyze_project(seed.project, seed.system_admin)

      assert resource_id == malformed_page.resource.id
      assert storage_snapshot(seed) == before_analysis
    end
  end

  describe "fixture foundation for later phases" do
    test "helpers create current Basic, Adaptive, shared, nested, and missing references", seed do
      activity = activity_fixture(seed, "Shared activity")

      basic_page =
        page_fixture(seed, "Nested Basic page", nested_reference_content(activity.resource.id))

      adaptive_page =
        page_fixture(
          seed,
          "Adaptive page",
          nested_reference_content(activity.resource.id)
          |> Map.put("advancedDelivery", true)
        )

      {shared_page_one, shared_page_two} = shared_page_fixtures(seed, activity.resource.id)
      missing_activity_id = missing_activity_resource_id()

      missing_page =
        page_fixture(seed, "Missing activity page", nested_reference_content(missing_activity_id))

      # Each fixture must be the revision currently resolved from the working
      # publication; otherwise later tests could accidentally exercise stale rows.
      for page <- [basic_page, adaptive_page, shared_page_one, shared_page_two, missing_page] do
        resolved = AuthoringResolver.from_resource_id(seed.project.slug, page.resource.id)
        assert resolved.id == page.revision.id
      end

      assert adaptive_page.revision.content["advancedDelivery"] == true
      assert basic_page.revision.content["advancedDelivery"] == nil

      assert AuthoringResolver.from_resource_id(seed.project.slug, activity.resource.id).id ==
               activity.revision.id

      assert AuthoringResolver.from_resource_id(seed.project.slug, missing_activity_id) == nil
    end
  end

  # These helpers intentionally build real resources and working-publication
  # mappings. Later phases can extend their content without replacing the reliable
  # authoring setup established and verified in Phase 1.
  defp activity_fixture(seed, title) do
    Seeder.create_activity(%{title: title}, seed.publication, seed.project, seed.author)
  end

  defp page_fixture(seed, title, content) do
    Seeder.create_page(title, seed.publication, seed.project, seed.author, content)
  end

  defp shared_page_fixtures(seed, activity_resource_id) do
    content = nested_reference_content(activity_resource_id)

    {
      page_fixture(seed, "Shared page one", content),
      page_fixture(seed, "Shared page two", content)
    }
  end

  defp nested_reference_content(activity_resource_id) do
    %{
      "model" => [
        %{
          "id" => "outer-group",
          "type" => "group",
          "children" => [
            %{
              "id" => "nested-activity-reference",
              "type" => "activity-reference",
              "activity_id" => activity_resource_id,
              "children" => []
            }
          ]
        }
      ]
    }
  end

  defp activity_reference_content(activity_resource_ids, advanced_delivery \\ :missing) do
    # Nest references below two group levels to exercise the same recursive page
    # traversal used by duplication. Tests pass repeated ids deliberately so the
    # analysis MapSet contract is verified rather than assumed.
    content = %{
      "model" => [
        %{
          "id" => "outer-group",
          "type" => "group",
          "children" => [
            %{
              "id" => "inner-group",
              "type" => "group",
              "children" =>
                activity_resource_ids
                |> Enum.with_index()
                |> Enum.map(fn {activity_resource_id, index} ->
                  %{
                    "id" => "activity-reference-#{index}",
                    "type" => "activity-reference",
                    "activity_id" => activity_resource_id,
                    "customData" => %{"preserve" => index},
                    "children" => []
                  }
                end)
            }
          ]
        }
      ]
    }

    case advanced_delivery do
      :missing -> content
      value -> Map.put(content, "advancedDelivery", value)
    end
  end

  defp storage_snapshot(seed) do
    project_resource_ids =
      from(project_resource in ProjectResource,
        where: project_resource.project_id == ^seed.project.id,
        order_by: project_resource.resource_id,
        select: project_resource.resource_id
      )
      |> Repo.all()

    working_publication_mappings =
      Repo.all(
        from(mapping in PublishedResource,
          where: mapping.publication_id == ^seed.publication.id,
          order_by: [mapping.resource_id, mapping.id],
          select: %{
            id: mapping.id,
            resource_id: mapping.resource_id,
            revision_id: mapping.revision_id,
            locked_by_id: mapping.locked_by_id,
            lock_updated_at: mapping.lock_updated_at,
            updated_at: mapping.updated_at
          }
        )
      )

    current_revision_ids = Enum.map(working_publication_mappings, & &1.revision_id)

    relevant_sections =
      Repo.all(
        from(section in Section,
          where: section.base_project_id == ^seed.project.id,
          order_by: section.id
        )
      )

    relevant_section_ids = Enum.map(relevant_sections, & &1.id)

    # Global counts detect accidental inserts. Full scoped authoring rows and full
    # relevant delivery/learner rows additionally detect in-place changes. Current
    # revision projections include content because AC-003 specifically requires
    # proving analysis leaves page bodies and denormalized references untouched.
    %{
      resource_count: Repo.aggregate(Resource, :count, :id),
      revision_count: Repo.aggregate(Revision, :count, :id),
      project_resource_count: Repo.aggregate(ProjectResource, :count, :resource_id),
      published_resource_count: Repo.aggregate(PublishedResource, :count, :id),
      publication_count: Repo.aggregate(Publication, :count, :id),
      section_count: Repo.aggregate(Section, :count, :id),
      resource_access_count: Repo.aggregate(ResourceAccess, :count, :id),
      project: Repo.reload!(seed.project),
      publication: Repo.reload!(seed.publication),
      project_resources:
        Repo.all(
          from(project_resource in ProjectResource,
            where: project_resource.project_id == ^seed.project.id,
            order_by: project_resource.resource_id,
            select: %{
              project_id: project_resource.project_id,
              resource_id: project_resource.resource_id
            }
          )
        ),
      resources:
        Repo.all(
          from(resource in Resource,
            where: resource.id in ^project_resource_ids,
            order_by: resource.id,
            select: %{
              id: resource.id,
              inserted_at: resource.inserted_at,
              updated_at: resource.updated_at
            }
          )
        ),
      current_revisions:
        Repo.all(
          from(revision in Revision,
            where: revision.id in ^current_revision_ids,
            order_by: revision.id,
            select: %{
              id: revision.id,
              resource_id: revision.resource_id,
              title: revision.title,
              slug: revision.slug,
              deleted: revision.deleted,
              resource_scope: revision.resource_scope,
              content: revision.content,
              activity_refs: revision.activity_refs,
              updated_at: revision.updated_at
            }
          )
        ),
      working_publication_mappings: working_publication_mappings,
      sections: relevant_sections,
      resource_accesses:
        Repo.all(
          from(resource_access in ResourceAccess,
            where: resource_access.section_id in ^relevant_section_ids,
            order_by: resource_access.id
          )
        )
    }
  end

  defp current_revision(seed, page) do
    AuthoringResolver.from_resource_id(seed.project.slug, page.resource.id)
  end

  defp referenced_activity_ids(revision) do
    Utils.activity_references(revision.content)
  end

  defp activity_reference_node(revision, activity_resource_id) do
    revision.content
    |> Oli.Resources.PageContent.flat_filter(fn
      %{"type" => "activity-reference", "activity_id" => ^activity_resource_id} -> true
      _node -> false
    end)
    |> List.first()
  end

  defp assert_locks_released(seed, resource_ids) do
    for resource_id <- resource_ids do
      mapping = Publishing.get_published_resource!(seed.publication.id, resource_id)
      assert mapping.locked_by_id == nil
      assert mapping.lock_updated_at == nil
    end
  end

  defp attach_project_repair_telemetry(events) do
    handler_id = "project-repair-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end

  defp assert_repair_telemetry(status, stage, reason) do
    assert_receive {:telemetry_event, [:oli, :authoring, :project_repair, :repair, :stop],
                    %{count: 1, duration_ms: duration_ms}, metadata}

    assert is_integer(duration_ms)
    assert metadata.operation == :repair
    assert metadata.status == status
    assert metadata.failure_stage == stage
    assert metadata.failure_reason == reason
    refute Map.has_key?(metadata, :content)
    refute Map.has_key?(metadata, :title)
  end

  defp missing_activity_resource_id do
    # Start well above normal test ids, then prove absence so the fixture cannot
    # silently become valid as the shared SQL sandbox accumulates rows.
    candidate = 1_000_000_000 + System.unique_integer([:positive])
    assert Repo.get(Resource, candidate) == nil
    candidate
  end
end
