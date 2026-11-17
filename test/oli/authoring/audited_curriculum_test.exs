defmodule Oli.Authoring.AuditedCurriculumTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType

  setup do
    seeded = Seeder.base_project_with_resource2()
    Map.put(seeded, :context, Context.for_actor(seeded.author, source: :ui))
  end

  describe "update_page_options/4" do
    test "records page settings and the DOT switch separately", ctx do
      assert {:ok, _} =
               Audited.update_page_options(ctx.context, ctx.project, ctx.revision1.slug, %{
                 "title" => "Renamed",
                 "graded" => "true",
                 "ai_enabled" => "false"
               })

      settings = assert_audited(:authoring_settings_changed, project_id: ctx.project.id)
      assert settings.entity_type == :resource
      assert settings.changes["title"]["after"] == "Renamed"

      assert settings.changes["graded"] == %{
               "operation" => "set",
               "before" => false,
               "after" => true
             }

      dot = assert_audited(:dot_settings_changed, project_id: ctx.project.id)
      assert dot.changes["ai_enabled"]["after"] == false
    end

    test "a container's options are recorded on the container", ctx do
      root = AuthoringResolver.root_container(ctx.project.slug)

      assert {:ok, _} =
               Audited.update_page_options(ctx.context, ctx.project, root.slug, %{
                 "title" => "Course"
               })

      event = assert_audited(:authoring_settings_changed, project_id: ctx.project.id)
      assert event.entity_type == :container
    end

    test "fields the options modal does not edit are protected", ctx do
      root = AuthoringResolver.root_container(ctx.project.slug)

      for {slug, change} <- [
            {ctx.revision1.slug, %{"deleted" => "true"}},
            {root.slug, %{"children" => []}},
            {ctx.revision1.slug, %{"title" => "Renamed", "content" => %{"model" => []}}},
            {ctx.revision1.slug, %{"not_a_field_#{System.unique_integer([:positive])}" => 1}}
          ] do
        assert {:error, :protected} =
                 Audited.update_page_options(ctx.context, ctx.project, slug, change)
      end

      refute AuthoringResolver.from_resource_id(ctx.project.slug, ctx.revision1.resource_id).deleted
      assert AuthoringResolver.root_container(ctx.project.slug).children == root.children
      assert audit_events(:authoring_settings_changed, project_id: ctx.project.id) == []
    end

    test "saving the same options records nothing", ctx do
      assert {:ok, _} =
               Audited.update_page_options(ctx.context, ctx.project, ctx.revision1.slug, %{
                 "title" => ctx.revision1.title
               })

      assert audit_events(:authoring_settings_changed, project_id: ctx.project.id) == []
    end
  end

  describe "move_curriculum_entry/6 and reorder_curriculum_entry/6" do
    test "a move between containers records each container's children", ctx do
      root = AuthoringResolver.root_container(ctx.project.slug)
      unit = add_unit(ctx, root)
      root = AuthoringResolver.root_container(ctx.project.slug)

      assert {:ok, _} =
               Audited.move_curriculum_entry(
                 ctx.context,
                 ctx.revision1,
                 root,
                 unit,
                 ctx.author,
                 ctx.project
               )

      events = audit_events(:curriculum_changed, project_id: ctx.project.id)
      by_container = Map.new(events, &{&1.resource_id, &1})

      assert by_container[root.resource_id].entity_type == :container

      refute ctx.revision1.resource_id in by_container[root.resource_id].changes["children"][
               "after"
             ]

      assert by_container[unit.resource_id].changes["children"]["after"] == [
               ctx.revision1.resource_id
             ]

      assert [_one_operation] = events |> Enum.map(& &1.operation_id) |> Enum.uniq()
    end

    test "a reorder records the container's children before and after", ctx do
      root = AuthoringResolver.root_container(ctx.project.slug)
      moved = ctx.revision1.resource_id
      expected = Enum.reject(root.children, &(&1 == moved)) ++ [moved]

      assert {:ok, _} =
               Audited.reorder_curriculum_entry(
                 ctx.context,
                 root,
                 ctx.project,
                 ctx.author,
                 ctx.revision1.slug,
                 length(root.children)
               )

      event = assert_audited(:curriculum_changed, project_id: ctx.project.id)

      assert event.changes["children"] == %{
               "operation" => "set",
               "before" => root.children,
               "after" => expected
             }
    end

    test "an audit failure leaves the curriculum unchanged", ctx do
      root = AuthoringResolver.root_container(ctx.project.slug)
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} =
                 Audited.move_curriculum_entry(
                   ctx.context,
                   ctx.revision1,
                   root,
                   nil,
                   ctx.author,
                   ctx.project
                 )
      end)

      assert ctx.revision1.resource_id in AuthoringResolver.root_container(ctx.project.slug).children
    end
  end

  defp add_unit(ctx, root) do
    {:ok, unit} =
      ContainerEditor.add_new(
        root,
        %{
          title: "Unit",
          objectives: %{},
          children: [],
          content: %{"model" => []},
          resource_type_id: ResourceType.id_for_container()
        },
        ctx.author,
        ctx.project
      )

    unit
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
