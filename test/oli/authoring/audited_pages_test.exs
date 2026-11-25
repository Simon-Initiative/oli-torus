defmodule Oli.Authoring.AuditedPagesTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Authoring.Locks
  alias Oli.Publishing.AuthoringResolver

  setup do
    seeded = Seeder.base_project_with_resource2()

    {:acquired} =
      PageEditor.acquire_lock(seeded.project.slug, seeded.revision1.slug, seeded.author.email)

    Map.put(seeded, :context, Context.for_actor(seeded.author, source: :ui))
  end

  describe "edit_page/5" do
    test "identity and structure fields are protected", ctx do
      for update <- [%{"children" => []}, %{"resource_id" => 1}, %{scope: :banked}] do
        assert {:error, :protected} = save(ctx, update)
      end

      assert events(ctx) == []
    end

    test "a save that changes only text records nothing", ctx do
      assert {:ok, _} = save(ctx, %{"content" => content([paragraph("Edited text")])})
      assert events(ctx) == []
    end

    test "removing an activity reference records the activity's removal", ctx do
      activity = create_activity(ctx)
      {:ok, _} = save(ctx, %{"content" => content([paragraph("A"), reference(activity)])})

      assert {:ok, _} = save(ctx, %{"content" => content([paragraph("A")])})

      assert [event] = events(ctx)
      assert event.event_type == :authoring_content_removed
      assert event.entity_id == to_string(activity.resource_id)

      assert event.changes["deleted"] == %{
               "operation" => "set",
               "before" => false,
               "after" => true
             }

      assert AuthoringResolver.from_resource_id(ctx.project.slug, activity.resource_id).deleted

      # Bringing the reference back (undo) restores the activity without an event
      assert {:ok, _} = save(ctx, %{"content" => content([paragraph("A"), reference(activity)])})
      assert length(events(ctx)) == 1
      refute AuthoringResolver.from_resource_id(ctx.project.slug, activity.resource_id).deleted
    end

    test "deleting the page records its removal with the activities it embedded", ctx do
      activity = create_activity(ctx)
      {:ok, _} = save(ctx, %{"content" => content([reference(activity)])})

      assert {:ok, _} = save(ctx, %{deleted: true})

      assert [event] = events(ctx)
      assert event.event_type == :authoring_content_removed
      assert event.resource_id == ctx.revision1.resource_id
      assert event.details == %{"removed_activity_ids" => [activity.resource_id]}
    end

    test "page settings and bank selections record authoring_settings_changed", ctx do
      assert {:ok, _} =
               save(ctx, %{
                 "title" => "Renamed",
                 "graded" => true,
                 "content" => content([selection("s1", 2)])
               })

      assert [event] = events(ctx)
      assert event.event_type == :authoring_settings_changed
      assert event.entity_type == :resource

      assert event.changes["title"] == %{
               "operation" => "set",
               "before" => ctx.revision1.title,
               "after" => "Renamed"
             }

      assert event.changes["graded"] == %{
               "operation" => "set",
               "before" => false,
               "after" => true
             }

      assert event.changes["selection_rules"] == %{
               "operation" => "set",
               "before" => [],
               "after" => [%{"id" => "s1", "count" => 2, "logic" => logic()}]
             }

      assert {:ok, _} = save(ctx, %{"content" => content([selection("s1", 3)])})

      assert [_, edited] = events(ctx)

      assert edited.changes == %{
               "selection_rules" => %{
                 "operation" => "set",
                 "before" => [%{"id" => "s1", "count" => 2, "logic" => logic()}],
                 "after" => [%{"id" => "s1", "count" => 3, "logic" => logic()}]
               }
             }
    end

    test "objectives, ai_enabled, and triggers record their own events in one save", ctx do
      objective =
        insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_objective())

      assert {:ok, _} =
               save(ctx, %{
                 "objectives" => %{"attached" => [objective.resource_id]},
                 "ai_enabled" => true,
                 "content" =>
                   Map.put(content([paragraph("A")]), "trigger", %{
                     "id" => "t1",
                     "type" => "trigger",
                     "trigger_type" => "page",
                     "prompt" => "Greet the student"
                   })
               })

      by_type = Map.new(events(ctx), &{&1.event_type, &1})

      assert by_type.learning_objectives_changed.changes["objectives"]["after"] == %{
               "attached" => [objective.resource_id]
             }

      assert by_type.dot_settings_changed.changes["ai_enabled"]["after"] == true

      assert by_type.activation_settings_changed.changes["triggers"]["after"] == [
               %{"path" => "page", "trigger_type" => "page", "prompt" => "Greet the student"}
             ]

      assert Enum.all?(Map.values(by_type), &(&1.resource_id == ctx.revision1.resource_id))
      assert map_size(by_type) == 3
    end

    test "records nothing while another author holds the page lock", ctx do
      Locks.release(ctx.project.slug, ctx.publication.id, ctx.page1.id, ctx.author.id)

      {:acquired} =
        PageEditor.acquire_lock(ctx.project.slug, ctx.revision1.slug, ctx.author2.email)

      assert {:error, {:lock_not_acquired, _}} = save(ctx, %{"title" => "Renamed"})
      assert events(ctx) == []
    end

    test "an audit failure leaves the page unchanged", ctx do
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} = save(ctx, %{"title" => "Renamed"})
      end)

      assert AuthoringResolver.from_resource_id(ctx.project.slug, ctx.revision1.resource_id).title ==
               ctx.revision1.title
    end
  end

  defp save(ctx, update) do
    Audited.edit_page(ctx.context, ctx.project.slug, ctx.revision1.slug, ctx.author.email, update)
  end

  defp events(ctx) do
    Oli.Auditing.LogEvent
    |> where([e], e.project_id == ^ctx.project.id)
    |> order_by([e], asc: e.id)
    |> Repo.all()
  end

  defp create_activity(ctx) do
    {:ok, {revision, _}} =
      ActivityEditor.create(
        ctx.project.slug,
        "oli_multiple_choice",
        ctx.author,
        %{"stem" => "Q"},
        []
      )

    revision
  end

  defp content(model), do: %{"version" => "0.1.0", "model" => model}

  defp paragraph(text) do
    %{
      "type" => "content",
      "id" => "c1",
      "children" => [%{"type" => "p", "children" => [%{"text" => text}]}]
    }
  end

  defp reference(activity) do
    %{
      "type" => "activity-reference",
      "id" => "ref-#{activity.resource_id}",
      "activitySlug" => activity.slug,
      "purpose" => "none",
      "children" => []
    }
  end

  defp selection(id, count) do
    %{"type" => "selection", "id" => id, "count" => count, "logic" => logic()}
  end

  defp logic, do: %{"conditions" => nil}
end
