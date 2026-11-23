defmodule Oli.Authoring.AuditedActivitiesTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing.AuthoringResolver

  setup do
    seeded = Seeder.base_project_with_resource2()
    %{project: project, author: author, revision1: page} = seeded
    {:acquired} = PageEditor.acquire_lock(project.slug, page.slug, author.email)

    seeded
    |> Map.put(:context, Context.for_actor(author, source: :ui))
    |> Map.put(:activity, create_activity(project, author))
    |> Map.put(:activity2, create_activity(project, author))
  end

  describe "edit_activity/6" do
    test "a title or content change records nothing", ctx do
      assert {:ok, _} =
               save(ctx, ctx.activity, %{"title" => "Renamed", "content" => %{"stem" => "New"}})

      assert events(ctx) == []
    end

    test "objectives record learning_objectives_changed for the activity", ctx do
      assert {:ok, _} = save(ctx, ctx.activity, %{"objectives" => %{"1" => [4700]}})

      assert [event] = events(ctx)
      assert event.event_type == :learning_objectives_changed
      assert event.entity_type == :resource
      assert event.resource_id == ctx.activity.resource_id
      assert event.actor_type == :author
      assert event.changes["objectives"]["after"] == %{"1" => [4700]}
    end

    test "part triggers record activation_settings_changed", ctx do
      trigger = %{
        "id" => "t1",
        "type" => "trigger",
        "trigger_type" => "correct_answer",
        "prompt" => "Congratulate the student"
      }

      assert {:ok, _} =
               save(ctx, ctx.activity, %{
                 "authoring" => %{"parts" => [%{"id" => "1", "triggers" => [trigger]}]}
               })

      assert [event] = events(ctx)
      assert event.event_type == :activation_settings_changed

      assert event.changes["triggers"] == %{
               "operation" => "set",
               "before" => [],
               "after" => [
                 %{
                   "path" => "part:1:t1",
                   "trigger_type" => "correct_answer",
                   "prompt" => "Congratulate the student"
                 }
               ]
             }
    end

    test "records nothing while another author holds the lock", ctx do
      Oli.Authoring.Locks.release(
        ctx.project.slug,
        ctx.publication.id,
        ctx.page1.id,
        ctx.author.id
      )

      {:acquired} =
        PageEditor.acquire_lock(ctx.project.slug, ctx.revision1.slug, ctx.author2.email)

      assert {:error, {:lock_not_acquired, _}} =
               save(ctx, ctx.activity, %{"objectives" => %{"1" => [4700]}})

      assert events(ctx) == []
    end

    test "an audit failure leaves the activity unchanged", ctx do
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} = save(ctx, ctx.activity, %{"objectives" => %{"1" => [4700]}})
      end)

      assert AuthoringResolver.from_resource_id(ctx.project.slug, ctx.activity.resource_id).objectives ==
               ctx.activity.objectives
    end
  end

  describe "edit_activities/5" do
    test "records each activity's changes under one operation", ctx do
      updates = [
        %{"resource_id" => ctx.activity.resource_id, "objectives" => %{"1" => [4700]}},
        %{"resource_id" => ctx.activity2.resource_id, "objectives" => %{"1" => [4701]}}
      ]

      assert {:ok, [_, _]} =
               Audited.edit_activities(
                 ctx.context,
                 ctx.project.slug,
                 ctx.revision1.resource_id,
                 ctx.author.email,
                 updates
               )

      assert [first, second] = events(ctx)

      assert Enum.sort([first.resource_id, second.resource_id]) ==
               Enum.sort([ctx.activity.resource_id, ctx.activity2.resource_id])

      assert first.operation_id == second.operation_id
    end
  end

  defp save(ctx, activity, update) do
    Audited.edit_activity(
      ctx.context,
      ctx.project.slug,
      ctx.revision1.resource_id,
      activity.resource_id,
      ctx.author.email,
      update
    )
  end

  defp events(ctx) do
    Oli.Auditing.LogEvent
    |> where([e], e.project_id == ^ctx.project.id)
    |> order_by([e], asc: e.id)
    |> Repo.all()
  end

  defp create_activity(project, author) do
    {:ok, {revision, _}} =
      ActivityEditor.create(
        project.slug,
        "oli_multiple_choice",
        author,
        %{"stem" => "Q", "authoring" => %{"parts" => [%{"id" => "1"}]}},
        []
      )

    revision
  end
end
