defmodule Oli.Authoring.AuditedHistoryTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, ChangeTracker}
  alias Oli.Resources

  setup do
    seeded = Seeder.base_project_with_resource2()
    Map.put(seeded, :context, Context.for_actor(seeded.author, source: :ui))
  end

  describe "restore_revision/4" do
    test "restores an earlier revision as a new head and records the settings it changed", ctx do
      head = rename(ctx, "Renamed page")

      assert {:ok, restored} =
               Audited.restore_revision(
                 ctx.context,
                 ctx.project,
                 ctx.revision1.resource_id,
                 ctx.revision1.id
               )

      assert restored.title == ctx.revision1.title
      assert restored.content == ctx.revision1.content

      event = assert_audited(:authoring_content_replaced, project_id: ctx.project.id)
      assert event.resource_id == ctx.revision1.resource_id
      assert event.details == %{"reason" => "history_restore"}

      assert event.changes == %{
               "title" => %{
                 "operation" => "set",
                 "before" => "Renamed page",
                 "after" => ctx.revision1.title
               }
             }

      assert Enum.map(event.refs, &{&1["role"], &1["id"]}) == [
               {"previous", head.id},
               {"resulting", restored.id}
             ]

      refute inspect(event) =~ inspect(ctx.revision1.content)
    end

    test "a revision of another resource is not restored", ctx do
      assert {:error, :not_found} =
               Audited.restore_revision(
                 ctx.context,
                 ctx.project,
                 ctx.revision1.resource_id,
                 ctx.revision2.id
               )

      assert audit_events(:authoring_content_replaced, project_id: ctx.project.id) == []
    end

    test "an audit failure leaves the head unchanged", ctx do
      head = rename(ctx, "Renamed page")
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} =
                 Audited.restore_revision(
                   ctx.context,
                   ctx.project,
                   ctx.revision1.resource_id,
                   ctx.revision1.id
                 )
      end)

      assert AuthoringResolver.from_resource_id(ctx.project.slug, ctx.revision1.resource_id).id ==
               head.id
    end
  end

  describe "replace_revision_content/4" do
    test "replaces the content, clears the editing lock, and records the edit", ctx do
      publication = Publishing.project_working_publication(ctx.project.slug)
      other = Oli.Factory.insert(:author)

      {:acquired} =
        Oli.Authoring.Locks.acquire(
          ctx.project.slug,
          publication.id,
          ctx.revision1.resource_id,
          other.id
        )

      content = %{"model" => []}

      assert {:ok, revision} =
               Audited.replace_revision_content(
                 ctx.context,
                 ctx.project,
                 ctx.revision1.resource_id,
                 content
               )

      assert revision.content == content

      mapping = Publishing.get_published_resource!(publication.id, ctx.revision1.resource_id)
      assert mapping.locked_by_id == nil

      event = assert_audited(:authoring_content_replaced, project_id: ctx.project.id)
      assert event.details == %{"reason" => "json_edit"}
      assert event.changes == %{}
    end
  end

  describe "update_revision_attribute/5" do
    test "edits children in place and records the change", ctx do
      container = AuthoringResolver.root_container(ctx.project.slug)

      assert {:ok, updated} =
               Audited.update_revision_attribute(
                 ctx.context,
                 ctx.project,
                 container.id,
                 :children,
                 []
               )

      assert updated.id == container.id
      assert updated.children == []

      event = assert_audited(:authoring_content_replaced, project_id: ctx.project.id)
      assert event.entity_type == :resource
      assert event.details == %{"reason" => "attribute_edit"}

      assert event.changes["children"] == %{
               "operation" => "set",
               "before" => container.children,
               "after" => []
             }

      assert Enum.map(event.refs, &{&1["role"], &1["id"]}) == [{"resulting", container.id}]
    end

    test "other attributes are protected", ctx do
      assert {:error, :protected} =
               Audited.update_revision_attribute(
                 ctx.context,
                 ctx.project,
                 ctx.revision1.id,
                 :deleted,
                 true
               )

      refute Resources.get_revision!(ctx.revision1.id).deleted
    end

    test "a revision outside the project is not edited", ctx do
      other = Seeder.base_project_with_resource2()

      assert {:error, :not_found} =
               Audited.update_revision_attribute(
                 ctx.context,
                 ctx.project,
                 other.revision1.id,
                 :objectives,
                 %{"attached" => []}
               )
    end
  end

  describe "import_metadata_row/4" do
    test "updates the revision in place and records the duration change", ctx do
      assert {:ok, updated} =
               Audited.import_metadata_row(ctx.context, ctx.project, ctx.revision1.slug, %{
                 duration_minutes: 15,
                 poster_image: "https://example.com/poster.png",
                 intro_video: nil,
                 intro_content: nil
               })

      assert updated.id == ctx.revision1.id
      assert updated.duration_minutes == 15

      event = assert_audited(:authoring_content_replaced, project_id: ctx.project.id)
      assert event.details == %{"reason" => "metadata_csv"}

      assert event.changes == %{
               "duration_minutes" => %{"operation" => "set", "before" => nil, "after" => 15}
             }
    end

    test "a row with the current values records nothing", ctx do
      assert {:ok, :unchanged} =
               Audited.import_metadata_row(ctx.context, ctx.project, ctx.revision1.slug, %{
                 duration_minutes: ctx.revision1.duration_minutes,
                 poster_image: ctx.revision1.poster_image,
                 intro_video: ctx.revision1.intro_video,
                 intro_content: ctx.revision1.intro_content
               })

      assert audit_events(:authoring_content_replaced, project_id: ctx.project.id) == []
    end

    test "an unknown slug fails", ctx do
      assert {:error, :not_found} =
               Audited.import_metadata_row(ctx.context, ctx.project, "no-such-page", %{
                 duration_minutes: 5
               })
    end
  end

  defp rename(ctx, title) do
    {:ok, revision} =
      Resources.create_revision_from_previous(ctx.revision1, %{
        title: title,
        author_id: ctx.author.id
      })

    {:ok, revision} = ChangeTracker.track_revision(ctx.project.slug, revision)
    revision
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
