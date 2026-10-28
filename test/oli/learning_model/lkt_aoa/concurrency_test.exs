defmodule Oli.LearningModel.LktAoa.ConcurrencyTest do
  use Oli.DataCase

  alias Oli.LearningModel
  alias Oli.LearningModel.{AttemptApplication, LearningState, PriorActivityPartEvidence}
  alias Oli.LearningModel.LktAoaFixtures

  test "two workers claiming the same evaluated PartAttempt apply it once" do
    %{section: section, group: group, user: user, objectives: [objective]} =
      LktAoaFixtures.lkt_fixture()

    results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn -> LearningModel.apply_evaluated_attempts(section, group) end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, %{status: :applied}}, &1)) == 1
    assert Enum.count(results, &match?({:ok, %{status: :noop}}, &1)) == 1
    assert Repo.aggregate(AttemptApplication, :count) == 1
    assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1

    state =
      Repo.get_by!(LearningState,
        section_id: section.id,
        user_id: user.id,
        learning_objective_id: objective.id
      )

    assert state.attempt_count == 1
    assert state.unique_activity_part_count == 1
  end

  test "concurrent first attempts for the same state do not lose proficiency updates or double first evidence" do
    %{section: section, group: first_group, user: user, objectives: [objective]} =
      LktAoaFixtures.lkt_fixture()

    second_group =
      LktAoaFixtures.add_attempt(first_group,
        part_id: "part-1",
        date_evaluated: DateTime.add(~U[2026-08-24 12:00:00Z], 60, :second),
        score: 0.0
      )

    [first, second] =
      [first_group, second_group]
      |> Enum.map(fn group ->
        Task.async(fn -> LearningModel.apply_evaluated_attempts(section, group) end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert {:ok, %{status: :applied}} = first
    assert {:ok, %{status: :applied}} = second

    state =
      Repo.get_by!(LearningState,
        section_id: section.id,
        user_id: user.id,
        learning_objective_id: objective.id
      )

    assert state.attempt_count == 2
    assert state.unique_activity_part_count == 1
    assert Repo.aggregate(AttemptApplication, :count) == 2
    assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1
  end

  @tag timeout: 120_000
  test "repeated higher-contention overlapping batches keep exact claim, state, and evidence counts" do
    %{section: section, group: first_group, user: user, objectives: [objective]} =
      LktAoaFixtures.lkt_fixture()

    groups =
      [
        first_group
        | Enum.map(1..9, fn index ->
            LktAoaFixtures.add_attempt(first_group,
              part_id: "part-1",
              date_evaluated: DateTime.add(~U[2026-08-24 12:00:00Z], index, :second),
              score: if(rem(index, 2) == 0, do: 1.0, else: 0.0)
            )
          end)
      ]

    results =
      groups
      |> Enum.map(fn group ->
        Task.async(fn -> LearningModel.apply_evaluated_attempts(section, group) end)
      end)
      |> Enum.map(&Task.await(&1, 10_000))

    assert Enum.all?(results, &match?({:ok, %{status: :applied}}, &1))
    assert Repo.aggregate(AttemptApplication, :count) == 10
    assert Repo.aggregate(PriorActivityPartEvidence, :count) == 1

    state =
      Repo.get_by!(LearningState,
        section_id: section.id,
        user_id: user.id,
        learning_objective_id: objective.id
      )

    assert state.attempt_count == 10
    assert state.unique_activity_part_count == 1
  end
end
