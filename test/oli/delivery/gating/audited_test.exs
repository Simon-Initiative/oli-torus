defmodule Oli.Delivery.Gating.AuditedTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Delivery.Gating.Audited, as: GatingAudited
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Seeder

  setup do
    seeds =
      Seeder.base_project_with_resource4()
      |> Seeder.add_users_to_section(:section_1, [:user_a])

    instructor = insert(:user)

    Map.merge(seeds, %{
      instructor: instructor,
      context: Context.for_actor(instructor, source: :ui)
    })
  end

  describe "gates" do
    test "a schedule gate, its student exception, and their removal record gating_changed", %{
      section_1: section,
      page1: page,
      user_a: student,
      context: context,
      instructor: instructor
    } do
      start = ~U[2099-01-01 00:00:00Z]

      assert {:ok, gate} =
               GatingAudited.create_gate(context, section, %{
                 resource_id: page.id,
                 type: :schedule,
                 data: %{start_datetime: start}
               })

      created =
        assert_audited(:gating_changed,
          section_id: section.id,
          resource_id: page.id,
          actor: instructor
        )

      assert {created.entity_type, created.entity_id} == {:gating_condition, to_string(gate.id)}
      assert created.affected_user_id == nil
      assert created.changes["type"] == %{"operation" => "set", "after" => "schedule"}

      assert created.changes["start_datetime"] == %{
               "operation" => "set",
               "after" => DateTime.to_iso8601(start)
             }

      assert {:ok, exception} =
               GatingAudited.create_gate(context, section, %{
                 resource_id: page.id,
                 type: :always_open,
                 parent_id: gate.id,
                 user_id: student.id
               })

      exception_event = assert_audited(:gating_changed, affected_user_id: student.id)
      assert exception_event.entity_id == to_string(exception.id)

      # Deleting the gate deletes its exception and records both
      assert {:ok, _deleted} = GatingAudited.delete_gate(context, section, gate)

      assert [_created, _exception, gate_removed, exception_removed] =
               audit_events(:gating_changed, section_id: section.id)

      assert gate_removed.entity_id == to_string(gate.id)
      assert gate_removed.changes["type"] == %{"operation" => "set", "before" => "schedule"}
      assert exception_removed.affected_user_id == student.id
      assert gate_removed.operation_id == exception_removed.operation_id
      refute Repo.get(GatingCondition, exception.id)
    end

    test "a prerequisite records prerequisite_changed with its source resource", %{
      section_1: section,
      page1: page,
      page2: source,
      context: context
    } do
      assert {:ok, gate} =
               GatingAudited.create_gate(context, section, %{
                 resource_id: page.id,
                 type: :finished,
                 data: %{resource_id: source.id, minimum_percentage: 0.5}
               })

      created = assert_audited(:prerequisite_changed, section_id: section.id)

      assert created.changes["source_resource_id"] == %{
               "operation" => "set",
               "after" => source.id
             }

      assert {:ok, _} =
               GatingAudited.update_gate(context, section, gate, %{
                 data: %{resource_id: source.id, minimum_percentage: 0.7}
               })

      [_created, updated] = audit_events(:prerequisite_changed, section_id: section.id)

      assert updated.changes == %{
               "minimum_percentage" => %{"operation" => "set", "before" => 0.5, "after" => 0.7}
             }

      # The same values again record nothing
      assert {:ok, _} =
               GatingAudited.update_gate(context, section, gate, %{
                 data: %{resource_id: source.id, minimum_percentage: 0.7}
               })

      assert length(audit_events(:prerequisite_changed, section_id: section.id)) == 2
    end

    test "a gate of another section is not found", %{
      section_1: section,
      section_2: other,
      page1: page,
      context: context
    } do
      gate = gating_condition_fixture(%{section_id: other.id, resource_id: page.id})

      assert {:error, :gating_condition_not_found} =
               GatingAudited.delete_gate(context, section, gate)

      assert Repo.get(GatingCondition, gate.id)
    end

    test "nothing is written when the event cannot be recorded", %{
      section_1: section,
      page1: page,
      context: context
    } do
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 GatingAudited.create_gate(context, section, %{
                   resource_id: page.id,
                   type: :schedule,
                   data: %{start_datetime: ~U[2099-01-01 00:00:00Z]}
                 })
               end)

      assert Repo.aggregate(GatingCondition, :count) == 0

      assert Sections.get_section!(section.id).resource_gating_index ==
               section.resource_gating_index
    end
  end

  describe "schedule" do
    test "an update records one event per section resource whose schedule changed", %{
      section_1: section,
      page1: page1,
      page2: page2,
      context: context,
      instructor: instructor
    } do
      first = Sections.get_section_resource(section.id, page1.id)
      second = Sections.get_section_resource(section.id, page2.id)

      updates = [
        schedule_update(first, "due_by", "2099-03-01"),
        schedule_update(second, to_string(second.scheduling_type), nil, second)
      ]

      assert {:ok, 2} = SectionsAudited.update_schedule(context, section, updates, "Etc/UTC")

      changed =
        assert_audited(:curriculum_schedule_changed,
          section_id: section.id,
          resource_id: page1.id,
          actor: instructor
        )

      assert changed.entity_type == :section_resource
      assert changed.entity_id == "section:#{section.id}/resource:#{page1.id}"
      assert changed.changes["end_date"]["after"] =~ "2099-03-01"
      assert changed.changes["scheduling_type"]["after"] == "due_by"

      # The second row was written with its own values
      assert audit_events(:curriculum_schedule_changed, resource_id: page2.id) == []

      # An empty update records nothing
      assert {:ok, 0} = SectionsAudited.update_schedule(context, section, [], "Etc/UTC")
      assert length(audit_events(:curriculum_schedule_changed, section_id: section.id)) == 1
    end

    test "the generic section resource writer refuses scheduling fields", %{
      section_1: section,
      page1: page1
    } do
      section_resource = Sections.get_section_resource(section.id, page1.id)

      for attrs <- [%{scheduling_type: :due_by}, %{"manually_scheduled" => true}] do
        assert {:error, :protected} = Sections.update_section_resource(section_resource, attrs)
      end
    end

    test "clearing records one event per section resource that had dates", %{
      section_1: section,
      page1: page1,
      context: context
    } do
      first = Sections.get_section_resource(section.id, page1.id)

      {:ok, 1} =
        SectionsAudited.update_schedule(
          audit_context(),
          section,
          [schedule_update(first, "due_by", "2099-03-01")],
          "Etc/UTC"
        )

      assert {:ok, 1} = SectionsAudited.clear_schedule(context, section)

      [_set, cleared] = audit_events(:curriculum_schedule_changed, resource_id: page1.id)
      assert cleared.changes["end_date"]["after"] == nil
      assert Sections.get_section_resource(section.id, page1.id).end_date == nil
    end

    test "nothing is written when the events cannot be recorded", %{
      section_1: section,
      page1: page1,
      context: context
    } do
      first = Sections.get_section_resource(section.id, page1.id)
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 SectionsAudited.update_schedule(
                   context,
                   section,
                   [schedule_update(first, "due_by", "2099-03-01")],
                   "Etc/UTC"
                 )
               end)

      assert Sections.get_section_resource(section.id, page1.id).end_date == first.end_date
    end
  end

  defp schedule_update(section_resource, scheduling_type, end_date, current \\ nil) do
    %{
      "id" => section_resource.id,
      "scheduling_type" => scheduling_type,
      "start_date" => current && date(current.start_date),
      "end_date" => end_date || (current && date(current.end_date)),
      "manually_scheduled" => section_resource.manually_scheduled || false,
      "removed_from_schedule" => section_resource.removed_from_schedule
    }
  end

  defp date(nil), do: nil
  defp date(%DateTime{} = date_time), do: Calendar.strftime(date_time, "%Y-%m-%d %H:%M:%S")

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
