defmodule Oli.Authoring.AuditedContentTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Editing.{ActivityEditor, BibEntryEditor, ResourceEditor}
  alias Oli.Authoring.Locks
  alias Oli.Authoring.MediaLibrary
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.ResourceType

  setup do
    seeded = Seeder.base_project_with_resource2()
    Map.put(seeded, :context, Context.for_actor(seeded.author, source: :ui))
  end

  describe "remove_from_curriculum/5" do
    test "records the removed page with the activities it embedded", %{
      author: author,
      context: context,
      project: project,
      revision1: page
    } do
      activity = create_activity(project, author)
      already_deleted = create_activity(project, author)
      ResourceEditor.edit(project.slug, already_deleted.resource_id, author, %{deleted: true})

      {:ok, page} =
        Resources.update_revision(page, %{
          content: %{
            "model" => [
              %{"type" => "activity-reference", "activity_id" => activity.resource_id},
              %{"type" => "activity-reference", "activity_id" => already_deleted.resource_id}
            ]
          }
        })

      container = AuthoringResolver.root_container(project.slug)

      assert {:ok, _container} =
               Audited.remove_from_curriculum(context, container, project, author, page.slug)

      event =
        assert_audited(:authoring_content_removed,
          project_id: project.id,
          actor: author,
          source: :ui
        )

      deleted = AuthoringResolver.from_resource_id(project.slug, page.resource_id)
      assert deleted.deleted
      assert event.entity_type == :resource
      assert event.entity_id == to_string(page.resource_id)
      assert event.resource_id == page.resource_id
      assert event.entity_snapshot["title"] == page.title

      assert event.changes == %{
               "deleted" => %{"operation" => "set", "before" => false, "after" => true}
             }

      assert event.details == %{"removed_activity_ids" => [activity.resource_id]}

      assert [
               %{"role" => "previous", "type" => "revision", "id" => page.id},
               %{"role" => "resulting", "type" => "revision", "id" => deleted.id}
             ] == Enum.map(event.refs, &Map.delete(&1, "label"))
    end

    test "records nothing while another author holds the page lock", %{
      author: author,
      author2: author2,
      context: context,
      page1: page_resource,
      project: project,
      publication: publication,
      revision1: page
    } do
      {:acquired} = Locks.acquire(project.slug, publication.id, page_resource.id, author2.id)
      container = AuthoringResolver.root_container(project.slug)

      assert {:error, {:lock_not_acquired, _}} =
               Audited.remove_from_curriculum(context, container, project, author, page.slug)

      assert audit_events(:authoring_content_removed, project_id: project.id) == []
    end

    test "an audit failure leaves the page in place", %{
      author: author,
      context: context,
      project: project,
      revision1: page
    } do
      reject_audit_inserts()
      container = AuthoringResolver.root_container(project.slug)

      capture_log(fn ->
        assert {:error, _} =
                 Audited.remove_from_curriculum(context, container, project, author, page.slug)
      end)

      refute AuthoringResolver.from_resource_id(project.slug, page.resource_id).deleted
      assert page.resource_id in AuthoringResolver.root_container(project.slug).children
    end
  end

  describe "delete_unattached_page/3" do
    test "records the deleted page once", %{context: context, project: project, revision2: page} do
      assert {:ok, _} = Audited.delete_unattached_page(context, project, page.slug)
      assert {:ok, _} = Audited.delete_unattached_page(context, project, page.slug)

      event = assert_audited(:authoring_content_removed, project_id: project.id)
      assert event.resource_id == page.resource_id
      assert event.details == %{}
    end
  end

  describe "delete_activity/5 and delete_activities/4" do
    test "embedded activities record content removal and banked ones a bank question", %{
      author: author,
      context: context,
      project: project,
      publication: publication
    } do
      embedded = create_activity(project, author)
      banked = create_activity(project, author, "banked")
      {:acquired} = Locks.acquire(project.slug, publication.id, embedded.resource_id, author.id)

      assert {:ok, _} =
               Audited.delete_activity(
                 context,
                 project.slug,
                 embedded.resource_id,
                 embedded.resource_id,
                 author
               )

      assert {:ok, {:ok, [_]}} =
               Audited.delete_activities(context, project.slug, [banked.resource_id], author)

      removed = assert_audited(:authoring_content_removed, project_id: project.id)
      assert removed.resource_id == embedded.resource_id

      bank = assert_audited(:bank_question_deleted, project_id: project.id)
      assert bank.resource_id == banked.resource_id
      assert bank.changes["deleted"]["after"] == true
    end

    test "a bulk deletion with one failure deletes and records nothing", %{
      author: author,
      context: context,
      project: project,
      publication: publication,
      author2: author2
    } do
      first = create_activity(project, author)
      locked = create_activity(project, author)
      {:acquired} = Locks.acquire(project.slug, publication.id, locked.resource_id, author2.id)

      assert {:error, _} =
               Audited.delete_activities(
                 context,
                 project.slug,
                 [first.resource_id, locked.resource_id],
                 author
               )

      refute AuthoringResolver.from_resource_id(project.slug, first.resource_id).deleted
      assert audit_events(:authoring_content_removed, project_id: project.id) == []
    end
  end

  describe "delete_alternatives_group/4 and delete_bib_entry/4" do
    test "record the deleted resource", %{author: author, context: context, project: project} do
      {:ok, group} =
        ResourceEditor.create(project.slug, author, ResourceType.id_for_alternatives(), %{
          title: "Reading mode",
          content: %{"options" => []}
        })

      {:ok, {:ok, entry}} =
        BibEntryEditor.create(project.slug, author, %{
          title: "A reference",
          content: %{"data" => []},
          author_id: author.id
        })

      assert {:ok, _} =
               Audited.delete_alternatives_group(context, project.slug, group.resource_id, author)

      assert {:ok, _} =
               Audited.delete_bib_entry(
                 context,
                 project.slug,
                 to_string(entry.resource_id),
                 author
               )

      assert [group_event, entry_event] =
               audit_events(:authoring_content_removed, project_id: project.id)

      assert group_event.entity_snapshot["title"] == "Reading mode"
      assert entry_event.resource_id == entry.resource_id
    end
  end

  describe "delete_media/3" do
    test "records each item that was not deleted yet, in the item's own project", %{
      context: context,
      project: project
    } do
      other_project = insert(:project)
      item = media_item(project, "photo.png")
      already_deleted = media_item(project, "old.png", deleted: true)
      foreign = media_item(other_project, "foreign.png")

      assert {:ok, 3} =
               Audited.delete_media(context, project.slug, [
                 item.id,
                 already_deleted.id,
                 foreign.id
               ])

      event = assert_audited(:media_deleted, project_id: project.id)
      assert event.entity_type == :media_item
      assert event.entity_id == to_string(item.id)
      assert event.details == %{"file_name" => "photo.png", "mime_type" => "image/png"}

      foreign_event = assert_audited(:media_deleted, project_id: other_project.id)
      assert foreign_event.entity_id == to_string(foreign.id)
    end
  end

  defp create_activity(project, author, scope \\ "embedded") do
    {:ok, {revision, _}} =
      ActivityEditor.create(
        project.slug,
        "oli_multiple_choice",
        author,
        %{"stem" => "Question"},
        [],
        scope
      )

    revision
  end

  defp media_item(project, file_name, attrs \\ []) do
    {:ok, item} =
      MediaLibrary.create_media_item(%{
        project_id: project.id,
        url: "https://example.com/#{file_name}",
        file_name: file_name,
        mime_type: "image/png",
        file_size: 10,
        md5_hash: "#{file_name}-hash",
        deleted: Keyword.get(attrs, :deleted, false)
      })

    item
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
