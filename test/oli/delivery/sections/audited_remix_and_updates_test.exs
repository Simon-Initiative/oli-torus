defmodule Oli.Delivery.Sections.AuditedRemixAndUpdatesTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Delivery.Updates.Worker
  alias Oli.Utils.Seeder

  # A section of the sample project: Unit 1 with "Unscored page one" and "Scored page two"
  setup do
    author = insert(:author)

    seeds =
      Seeder.Project.create_sample_project(%{}, author,
        project_tag: :project,
        publication_tag: :publication
      )

    Seeder.Project.ensure_published(seeds, seeds.publication)
    publication = Oli.Publishing.get_latest_published_publication_by_slug(seeds.project.slug)

    {:ok, section} =
      SectionsAudited.create_section_from_publication(
        audit_context(),
        publication,
        %{
          title: "Remix",
          type: :enrollable,
          base_project_id: seeds.project.id,
          context_id: UUID.uuid4()
        },
        rebuild: true
      )

    instructor = insert(:user)

    %{
      author: author,
      project: seeds.project,
      publication: publication,
      section: section,
      instructor: instructor,
      context: Context.for_actor(instructor, source: :ui)
    }
  end

  describe "save_remix/3" do
    test "records one event per entry that moved or was hidden, as the instructor", %{
      section: section,
      author: author,
      instructor: instructor,
      context: context
    } do
      {:ok, state} = Remix.init(section, author)
      [unit] = state.active.children
      [first, second] = unit.children
      {:ok, state} = Remix.select_active(state, unit.uuid)

      # The second page moves first, and the former first page is hidden
      {:ok, state} = Remix.reorder(state, 1, 0)
      {:ok, state} = Remix.toggle_hidden(state, first.uuid)

      assert {:ok, _section} = SectionsAudited.save_remix(context, state, author)

      hidden =
        assert_audited(:section_remix_saved,
          section_id: section.id,
          resource_id: first.resource_id,
          actor: instructor
        )

      assert hidden.source == :ui
      assert hidden.entity_type == :curriculum_entry
      assert hidden.entity_id == "section:#{section.id}/resource:#{first.resource_id}"
      assert hidden.entity_snapshot["title"] == "Unscored page one"

      assert hidden.changes["hidden"] == %{
               "operation" => "set",
               "before" => false,
               "after" => true
             }

      assert hidden.changes["position"] == %{"operation" => "set", "before" => 1, "after" => 2}

      moved = assert_audited(:section_remix_saved, resource_id: second.resource_id)
      assert moved.changes["position"] == %{"operation" => "set", "before" => 2, "after" => 1}
      refute Map.has_key?(moved.changes, "hidden")

      # The unit itself did not change
      assert audit_events(:section_remix_saved, resource_id: unit.resource_id) == []

      # Both events belong to the same save
      assert hidden.operation_id == moved.operation_id
    end

    test "a removed entry records its last position, with no after-state", %{
      section: section,
      author: author,
      context: context
    } do
      {:ok, state} = Remix.init(section, author)
      [unit] = state.active.children
      [_first, second] = unit.children
      {:ok, state} = Remix.remove(state, second.uuid)

      assert {:ok, _section} = SectionsAudited.save_remix(context, state, author)

      removed = assert_audited(:section_remix_saved, resource_id: second.resource_id)
      assert removed.changes["position"] == %{"operation" => "set", "before" => 2}
      assert removed.changes["parent"] == %{"operation" => "set", "before" => unit.resource_id}
      assert removed.refs == []
    end

    test "an entry moved to another container records its new parent and position", %{
      section: section,
      author: author,
      context: context
    } do
      {:ok, state} = Remix.init(section, author)
      root = state.active
      [unit] = root.children
      [_first, second] = unit.children
      {:ok, state} = Remix.move(state, second.uuid, root.uuid)

      assert {:ok, _section} = SectionsAudited.save_remix(context, state, author)

      moved = assert_audited(:section_remix_saved, resource_id: second.resource_id)

      assert moved.changes["parent"] == %{
               "operation" => "set",
               "before" => unit.resource_id,
               "after" => root.resource_id
             }

      position = Enum.find_index(state.hierarchy.children, &(&1.uuid == second.uuid)) + 1
      assert moved.changes["position"]["after"] == position
    end

    test "the generic section resource writer refuses the fields a remix saves", %{
      section: section
    } do
      [unit_id | _] = section |> Remix.init(insert(:author)) |> elem(1) |> unit_ids()
      section_resource = Sections.get_section_resource(section.id, unit_id)

      for attrs <- [%{hidden: true}, %{"numbering_index" => 9}] do
        assert {:error, :protected} = Sections.update_section_resource(section_resource, attrs)
      end
    end

    test "a save without changes records nothing", %{
      section: section,
      author: author,
      context: context
    } do
      {:ok, state} = Remix.init(section, author)

      assert {:ok, _section} = SectionsAudited.save_remix(context, state, author)
      assert audit_events(:section_remix_saved, section_id: section.id) == []
    end

    test "nothing is written when the events cannot be recorded", %{
      section: section,
      author: author,
      context: context
    } do
      {:ok, state} = Remix.init(section, author)
      [unit] = state.active.children
      {:ok, state} = Remix.toggle_hidden(state, unit.uuid)
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn -> SectionsAudited.save_remix(context, state, author) end)

      refute Sections.get_section_resource(section.id, unit.resource_id).hidden
    end
  end

  describe "apply_publication_update/3" do
    test "records the previous and resulting publications once; a rerun records nothing", %{
      section: section,
      project: project,
      publication: previous,
      author: author,
      context: context,
      instructor: instructor
    } do
      resulting = publish(project, author)

      assert {:ok, _} = SectionsAudited.apply_publication_update(context, section, resulting.id)

      applied =
        assert_audited(:publication_applied,
          section_id: section.id,
          project_id: project.id,
          actor: instructor
        )

      assert {applied.entity_type, applied.entity_id} == {:section, to_string(section.id)}

      assert applied.changes == %{
               "publication_id" => %{
                 "operation" => "set",
                 "before" => previous.id,
                 "after" => resulting.id
               }
             }

      assert [
               %{"role" => "previous", "type" => "publication", "id" => previous_id},
               %{"role" => "resulting", "type" => "publication", "id" => resulting_id}
             ] = applied.refs

      assert {previous_id, resulting_id} == {previous.id, resulting.id}

      # Applying it again finds it in place
      assert {:ok, _} = SectionsAudited.apply_publication_update(context, section, resulting.id)
      assert length(audit_events(:publication_applied, section_id: section.id)) == 1
    end

    test "nothing is written when the event cannot be recorded", %{
      section: section,
      project: project,
      publication: previous,
      author: author,
      context: context
    } do
      resulting = publish(project, author)
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 SectionsAudited.apply_publication_update(context, section, resulting.id)
               end)

      assert Sections.get_current_publication(section.id, project.id).id == previous.id
    end
  end

  describe "publication update jobs" do
    test "a job records the actor that enqueued it, under that operation", %{
      section: section,
      project: project,
      author: author,
      context: context,
      instructor: instructor
    } do
      resulting = publish(project, author)

      assert {:ok, job} =
               SectionsAudited.enqueue_publication_update(context, section, resulting.id)

      assert {:ok, _} = perform_job(Worker, job.args)

      applied = assert_audited(:publication_applied, section_id: section.id, actor: instructor)
      assert applied.source == :job
      assert applied.parent_operation_id == context.operation_id
    end

    test "a job enqueued without an actor records scheduled maintenance", %{
      section: section,
      project: project,
      author: author
    } do
      resulting = publish(project, author)

      assert {:ok, _} =
               perform_job(Worker, %{
                 "section_slug" => section.slug,
                 "publication_id" => resulting.id
               })

      applied = assert_audited(:publication_applied, section_id: section.id)
      assert {applied.actor_type, applied.actor_key} == {:system, "scheduled_maintenance"}
      assert applied.source == :job
    end
  end

  defp unit_ids(state), do: Enum.map(state.active.children, & &1.resource_id)

  defp publish(project, author) do
    {:ok, publication} =
      Oli.Publishing.Audited.publish_project(audit_context(), project, "Next", author.id)

    publication
  end

  defp capture_log_result(fun) do
    {result, _log} = ExUnit.CaptureLog.with_log(fun)
    result
  end

  defp reject_audit_inserts do
    Repo.query!("""
    CREATE FUNCTION pg_temp.reject_audit_insert() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'audit insert rejected by test';
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_audit_insert BEFORE INSERT ON audit_log_events
      FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_audit_insert()
    """)
  end
end
