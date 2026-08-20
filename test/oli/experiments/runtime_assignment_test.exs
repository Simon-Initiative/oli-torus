defmodule Oli.Experiments.RuntimeAssignmentTest do
  use Oli.DataCase, async: true

  alias Oli.Experiments.{AssignmentDecision, AssignConditionRequest, RuntimeAssignment, Scope}
  alias Oli.Experiments.Schemas.{Assignment, ExperimentDefinition}
  alias Oli.Experiments.XAPI.ConditionAssignmentEmitter
  alias Oli.Repo

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

  test "page assignment emits each new assignment once after the batch transaction commits" do
    # AC-015: every event returned by the committed batch is emitted once outside the transaction.
    test_pid = self()
    scope = %Scope{}
    requests = [%AssignConditionRequest{}]

    decisions = [
      %AssignmentDecision{status: :assigned, assignment_id: 1, reused?: false},
      %AssignmentDecision{status: :assigned, assignment_id: 2, reused?: false}
    ]

    events = [%{assignment_id: 1}, %{assignment_id: 2}]

    dependencies = %{
      common_scope: fn ^requests -> {:ok, scope} end,
      require_delivery: fn ^scope -> :ok end,
      validate_publication: fn ^scope -> {:ok, scope} end,
      batch_assign: fn ^requests, ^scope -> {decisions, events} end,
      emit_committed: fn event ->
        send(test_pid, {:emitted, event.assignment_id, Repo.in_transaction?()})
      end
    }

    assert {:ok, ^decisions} =
             RuntimeAssignment.assign_page_conditions(requests, dependencies)

    assert_receive {:emitted, 1, false}
    assert_receive {:emitted, 2, false}
    refute_receive {:emitted, _, _}
  end

  test "page assignment emits nothing when the committed batch contains only sticky reuse" do
    test_pid = self()
    scope = %Scope{}
    requests = [%AssignConditionRequest{}]
    decisions = [%AssignmentDecision{status: :assigned, assignment_id: 1, reused?: true}]

    events = [
      %{
        assignment: %Assignment{},
        experiment: %ExperimentDefinition{},
        decision: hd(decisions),
        request: %AssignConditionRequest{scope: scope}
      }
    ]

    dependencies = %{
      common_scope: fn ^requests -> {:ok, scope} end,
      require_delivery: fn ^scope -> :ok end,
      validate_publication: fn ^scope -> {:ok, scope} end,
      batch_assign: fn ^requests, ^scope -> {decisions, events} end,
      emit_committed: fn event ->
        ConditionAssignmentEmitter.emit(
          event.assignment,
          event.experiment,
          event.decision,
          event.request.scope,
          fn _bundle -> send(test_pid, :emitted) end
        )
      end
    }

    assert {:ok, ^decisions} =
             RuntimeAssignment.assign_page_conditions(requests, dependencies)

    refute_receive :emitted
  end
end
