defmodule Oli.Experiments.RuntimeAssignmentTest do
  use Oli.DataCase, async: true

  alias Oli.Experiments.{AssignmentDecision, AssignConditionRequest, RuntimeAssignment}

  test "emits a committed assignment only for a newly persisted decision" do
    # AC-015: emission occurs only for the new-assignment result returned after commit.
    test_pid = self()
    request = %AssignConditionRequest{}

    event = %{assignment_id: 1}

    dependencies = %{
      assign: fn _request ->
        {:ok,
         %AssignmentDecision{
           status: :assigned,
           assignment_id: 1,
           reused?: false
         }, event}
      end,
      emit_committed_single: fn committed_event ->
        send(test_pid, {:emitted, committed_event.assignment_id})
      end
    }

    assert {:ok, %AssignmentDecision{assignment_id: 1}} =
             RuntimeAssignment.assign_condition(request, dependencies)

    assert_receive {:emitted, 1}
  end

  test "does not emit a committed assignment for sticky reuse" do
    test_pid = self()
    request = %AssignConditionRequest{}

    dependencies = %{
      assign: fn _request ->
        {:ok,
         %AssignmentDecision{
           status: :assigned,
           assignment_id: 1,
           reused?: true
         }}
      end,
      emit_committed_single: fn _event -> send(test_pid, :emitted) end
    }

    assert {:ok, %AssignmentDecision{reused?: true}} =
             RuntimeAssignment.assign_condition(request, dependencies)

    refute_receive :emitted
  end
end
