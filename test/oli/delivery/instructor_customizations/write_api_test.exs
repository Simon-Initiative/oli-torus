defmodule Oli.Delivery.InstructorCustomizations.WriteApiTest do
  use Oli.DataCase

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.SystemRole
  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Delivery.InstructorCustomizations.PageExclusions
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  setup do
    author = insert(:author)
    project = insert(:project, authors: [author])

    embedded_activity = activity_revision("Embedded activity", :embedded)
    candidates = Enum.map(1..3, &activity_revision("Candidate #{&1}", :banked))

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Basic page",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => embedded_activity.resource_id},
            selection("selection-1", 2),
            selection("selection-2", 1)
          ]
        }
      )

    adaptive_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Adaptive page",
        content: %{"advancedAuthoring" => true, "model" => []}
      )

    root_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root",
        children: [page_revision.resource_id, adaptive_revision.resource_id],
        content: %{}
      )

    revisions = [root_revision, page_revision, adaptive_revision, embedded_activity | candidates]

    Enum.each(revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: root_revision.resource_id)

    Enum.each(revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section = insert(:section, base_project: project)
    {:ok, section} = Sections.create_section_resources(section, publication)

    instructor = insert(:user)

    Sections.enroll(instructor.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    {:ok,
     %{
       section: section,
       page_revision: page_revision,
       adaptive_revision: adaptive_revision,
       embedded_activity: embedded_activity,
       candidates: candidates,
       instructor: instructor
     }}
  end

  describe "authorization and target validation" do
    test "resolves preview-route bank-selection targets through the public context", context do
      assert {:ok, page_revision, selection} =
               InstructorCustomizations.resolve_bank_selection_preview_target(
                 context.section,
                 context.page_revision.slug,
                 "selection-1"
               )

      assert page_revision.id == context.page_revision.id
      assert selection["id"] == "selection-1"
      assert selection["count"] == 2
    end

    test "returns page-not-found for an unknown preview revision slug", context do
      assert {:error, {:not_found, :page}} =
               InstructorCustomizations.resolve_bank_selection_preview_target(
                 context.section,
                 "missing-revision-slug",
                 "selection-1"
               )
    end

    test "returns adaptive-page errors for unsupported preview targets", context do
      assert {:error, {:invalid_page_type, :adaptive}} =
               InstructorCustomizations.resolve_bank_selection_preview_target(
                 context.section,
                 context.adaptive_revision.slug,
                 "selection-1"
               )
    end

    test "returns selection-not-found for an unknown bank selection id", context do
      assert {:error, {:not_found, :selection}} =
               InstructorCustomizations.resolve_bank_selection_preview_target(
                 context.section,
                 context.page_revision.slug,
                 "missing-selection"
               )
    end

    test "requires an instructor or admin-equivalent actor", context do
      unauthorized_user = insert(:user)

      assert {:error, {:unauthorized, :customize_section}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.page_revision.resource_id,
                 context.embedded_activity.resource_id
               )

      assert {:error, {:unauthorized, :customize_section}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.page_revision.resource_id,
                 context.embedded_activity.resource_id,
                 actor: unauthorized_user
               )

      assert {:error, {:unauthorized, :customize_section}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.page_revision.resource_id,
                 context.embedded_activity.resource_id,
                 actor: unauthorized_user,
                 authorize?: false
               )

      admin = insert(:author, system_role_id: SystemRole.role_id().content_admin)

      assert {:ok, %PageExclusions{}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.page_revision.resource_id,
                 context.embedded_activity.resource_id,
                 actor: admin
               )
    end

    test "validates section, page, page type, and targets", context do
      opts = [actor: context.instructor]
      missing_id = -1

      assert {:error, {:not_found, :section}} =
               InstructorCustomizations.exclude_activity(
                 missing_id,
                 context.page_revision.resource_id,
                 context.embedded_activity.resource_id,
                 opts
               )

      assert {:error, {:not_found, :page}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 missing_id,
                 context.embedded_activity.resource_id,
                 opts
               )

      assert {:error, {:invalid_page_type, :adaptive}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.adaptive_revision.resource_id,
                 context.embedded_activity.resource_id,
                 opts
               )

      assert {:error, {:not_found, :activity}} =
               InstructorCustomizations.exclude_activity(
                 context.section,
                 context.page_revision.resource_id,
                 missing_id,
                 opts
               )

      assert {:error, {:not_found, :selection}} =
               InstructorCustomizations.exclude_bank_selection(
                 context.section,
                 context.page_revision.resource_id,
                 "missing-selection",
                 opts
               )

      embedded_id = context.embedded_activity.resource_id

      assert {:error, {:invalid_selection_candidate, ^embedded_id}} =
               InstructorCustomizations.exclude_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 embedded_id,
                 opts
               )
    end
  end

  describe "idempotent writes" do
    test "disables and restores embedded activities and selections", context do
      opts = [actor: context.instructor]

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.exclude_activity(
                   context.section,
                   context.page_revision.resource_id,
                   context.embedded_activity.resource_id,
                   opts
                 )

        refute InstructorCustomizations.activity_enabled?(
                 view,
                 context.embedded_activity.resource_id
               )
      end

      assert exclusion_count(context, :embedded_activity) == 1

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.restore_activity(
                   context.section,
                   context.page_revision.resource_id,
                   context.embedded_activity.resource_id,
                   opts
                 )

        assert InstructorCustomizations.activity_enabled?(
                 view,
                 context.embedded_activity.resource_id
               )
      end

      assert exclusion_count(context, :embedded_activity) == 0

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.exclude_bank_selection(
                   context.section,
                   context.page_revision.resource_id,
                   "selection-1",
                   opts
                 )

        refute InstructorCustomizations.bank_selection_enabled?(view, "selection-1")
      end

      assert exclusion_count(context, :bank_selection) == 1

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.restore_bank_selection(
                   context.section,
                   context.page_revision.resource_id,
                   "selection-1",
                   opts
                 )

        assert InstructorCustomizations.bank_selection_enabled?(view, "selection-1")
      end

      assert exclusion_count(context, :bank_selection) == 0
    end

    test "disables and restores candidates while returning the refreshed view", context do
      candidate = hd(context.candidates)
      opts = [actor: context.instructor]

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.exclude_bank_candidate(
                   context.section,
                   context.page_revision.resource_id,
                   "selection-1",
                   candidate.resource_id,
                   opts
                 )

        refute InstructorCustomizations.bank_candidate_enabled?(
                 view,
                 "selection-1",
                 candidate.resource_id
               )
      end

      assert exclusion_count(context, :bank_candidate) == 1

      for _ <- 1..2 do
        assert {:ok, view} =
                 InstructorCustomizations.restore_bank_candidate(
                   context.section,
                   context.page_revision.resource_id,
                   "selection-1",
                   candidate.resource_id,
                   opts
                 )

        assert InstructorCustomizations.bank_candidate_enabled?(
                 view,
                 "selection-1",
                 candidate.resource_id
               )
      end

      assert exclusion_count(context, :bank_candidate) == 0
    end
  end

  describe "candidate count protection and review" do
    test "allows disables above count, blocks at count, and allows whole-selection disable",
         context do
      [first, second | _] = context.candidates
      opts = [actor: context.instructor]

      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 first.resource_id,
                 opts
               )

      assert {:error,
              {:insufficient_selection_candidates,
               %{selection_id: "selection-1", count: 2, active_candidates: 1}}} =
               InstructorCustomizations.exclude_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 second.resource_id,
                 opts
               )

      assert {:ok, view} =
               InstructorCustomizations.exclude_bank_selection(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 opts
               )

      refute InstructorCustomizations.bank_selection_enabled?(view, "selection-1")
    end

    test "blocks another disable when stale exclusions already leave the selection below count",
         context do
      [first, second, third] = context.candidates

      Enum.each([first, second], fn candidate ->
        insert_exclusion(context, :bank_candidate,
          selection_id: "selection-1",
          excluded_resource_id: candidate.resource_id
        )
      end)

      assert {:error,
              {:insufficient_selection_candidates,
               %{selection_id: "selection-1", count: 2, active_candidates: 0}}} =
               InstructorCustomizations.exclude_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 third.resource_id,
                 actor: context.instructor
               )
    end

    test "candidate disable locks the page row before enforcing count", context do
      handler_id = "candidate-lock-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          if is_binary(metadata.query) and
               String.contains?(metadata.query, ~s[FOR UPDATE]) and
               String.contains?(metadata.query, ~s["section_resources"]) do
            send(parent, :page_locked)
          end
        end,
        %{}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:ok, _view} =
               InstructorCustomizations.exclude_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 hd(context.candidates).resource_id,
                 actor: context.instructor
               )

      assert_receive :page_locked
    end

    test "lists candidates with selection and action state while ignoring stale exclusions",
         context do
      [first, second, _third] = context.candidates

      insert_exclusion(context, :bank_selection, selection_id: "selection-1")

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: first.resource_id
      )

      stale_activity = activity_revision("Stale activity", :banked)

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: stale_activity.resource_id
      )

      assert {:ok,
              %{
                selection_id: "selection-1",
                count: 2,
                selection_enabled?: false,
                active_count: 2,
                total_count: 3,
                has_more?: false,
                candidates: candidates
              }} =
               InstructorCustomizations.list_bank_selection_candidates(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1"
               )

      assert length(candidates) == 3
      refute Enum.any?(candidates, &(&1.activity_resource_id == stale_activity.resource_id))

      assert %{enabled?: false, disable_allowed?: true} =
               Enum.find(candidates, &(&1.activity_resource_id == first.resource_id))

      assert %{enabled?: true, disable_allowed?: false} =
               Enum.find(candidates, &(&1.activity_resource_id == second.resource_id))

      assert %{
               selection_enabled?: false,
               excluded_candidate_ids: excluded_candidate_ids
             } =
               InstructorCustomizations.get_selection_exclusion_view(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1"
               )

      assert excluded_candidate_ids == MapSet.new([first.resource_id, stale_activity.resource_id])
    end

    test "validates candidate-list paging and computes action state from all candidates",
         context do
      assert {:error, {:invalid_paging, :limit}} =
               InstructorCustomizations.list_bank_selection_candidates(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 limit: "1"
               )

      assert {:ok, %{candidates: [candidate], total_count: 3, has_more?: true, limit: 1}} =
               InstructorCustomizations.list_bank_selection_candidates(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 limit: 1
               )

      assert candidate.disable_allowed?
    end

    test "uses a standard default page size for candidate review", context do
      assert {:ok, %{candidates: candidates, total_count: 3, has_more?: false, active_count: 3}} =
               InstructorCustomizations.list_bank_selection_candidates(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1"
               )

      assert length(candidates) == 3
    end

    test "accepts an already resolved section/page_revision/selection target", context do
      selection = selection("selection-1", 2)

      assert {:ok,
              %{
                selection_id: "selection-1",
                count: 2,
                active_count: 3,
                total_count: 3,
                has_more?: false,
                candidates: candidates
              }} =
               InstructorCustomizations.list_bank_selection_candidates(
                 context.section,
                 context.page_revision,
                 selection,
                 []
               )

      assert length(candidates) == 3
    end

    test "lists all candidate activity type ids for a resolved selection target", context do
      selection = selection("selection-1", 2)

      assert {:ok, activity_type_ids} =
               InstructorCustomizations.list_bank_selection_candidate_activity_type_ids(
                 context.section,
                 context.page_revision,
                 selection,
                 3
               )

      assert Enum.sort(activity_type_ids) ==
               context.candidates
               |> Enum.map(& &1.activity_type_id)
               |> Enum.uniq()
               |> Enum.sort()
    end

    test "summarizes selection candidates without returning a paged candidate list", context do
      [first, second, third] = context.candidates

      insert_exclusion(context, :bank_selection, selection_id: "selection-1")

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: first.resource_id
      )

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: second.resource_id
      )

      assert {:ok,
              %{
                selection_id: "selection-1",
                count: 2,
                active_count: 1,
                selection_enabled?: false,
                sample_candidate: %{
                  activity_resource_id: activity_resource_id,
                  enabled?: true
                }
              }} =
               InstructorCustomizations.get_bank_selection_summary(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1"
               )

      assert activity_resource_id == third.resource_id
    end

    test "samples one active candidate while respecting candidate exclusions", context do
      [first, second, third] = context.candidates

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: first.resource_id
      )

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: second.resource_id
      )

      assert {:ok,
              %{
                activity_resource_id: activity_resource_id,
                enabled?: true
              }} =
               InstructorCustomizations.sample_bank_selection_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1"
               )

      assert activity_resource_id == third.resource_id
    end

    test "restores a stale candidate exclusion without requiring it to match current logic",
         context do
      stale_activity = activity_revision("Stale activity", :banked)

      insert_exclusion(context, :bank_candidate,
        selection_id: "selection-1",
        excluded_resource_id: stale_activity.resource_id
      )

      assert {:ok, view} =
               InstructorCustomizations.restore_bank_candidate(
                 context.section,
                 context.page_revision.resource_id,
                 "selection-1",
                 stale_activity.resource_id,
                 actor: context.instructor
               )

      assert InstructorCustomizations.bank_candidate_enabled?(
               view,
               "selection-1",
               stale_activity.resource_id
             )
    end
  end

  defp activity_revision(title, scope) do
    insert(:revision,
      resource_type_id: ResourceType.id_for_activity(),
      activity_type_id: Oli.Activities.get_registration_by_slug("oli_multiple_choice").id,
      title: title,
      scope: scope,
      content: %{"model" => %{"stem" => title}}
    )
  end

  defp selection(id, count) do
    %{"type" => "selection", "id" => id, "logic" => %{"conditions" => nil}, "count" => count}
  end

  defp exclusion_count(context, kind) do
    Repo.aggregate(
      from(exclusion in ActivityExclusion,
        where:
          exclusion.section_id == ^context.section.id and
            exclusion.page_resource_id == ^context.page_revision.resource_id and
            exclusion.kind == ^kind
      ),
      :count
    )
  end

  defp insert_exclusion(context, kind, attrs) do
    %ActivityExclusion{}
    |> ActivityExclusion.changeset(
      context.section.id,
      context.page_revision.resource_id,
      attrs |> Map.new() |> Map.put(:kind, kind)
    )
    |> Repo.insert!()
  end
end
