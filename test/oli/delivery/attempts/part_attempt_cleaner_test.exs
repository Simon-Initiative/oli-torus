defmodule Oli.Delivery.Attempts.PartAttemptCleanerTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.PartAttemptCleaner

  test "the sort with evaluated and active" do
    items = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-04 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-03 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-02 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]}
    ]

    # This should sort the evaluated item last, then the active ones by updated_at so that
    # the most recently updated one is next to last
    [item1, item2, item3, item4] = PartAttemptCleaner.sort(items)

    assert item1.id == 4
    assert item2.id == 3
    assert item3.id == 2
    assert item4.id == 1
  end

  test "the sort with submitted and active" do
    items = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :submitted,
        updated_at: ~U[2021-01-04 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-03 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-02 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]}
    ]

    # This should sort the submitted item last, then the active ones by updated_at so that
    # the most recently updated one is next to last
    [item1, item2, item3, item4] = PartAttemptCleaner.sort(items)

    assert item1.id == 4
    assert item2.id == 3
    assert item3.id == 2
    assert item4.id == 1
  end

  test "the sort with submitted and active and evaluated" do
    items = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :submitted,
        updated_at: ~U[2021-01-04 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :evaluated, updated_at: ~U[2021-01-03 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-02 00:00:00.000Z]}
    ]

    # This should sort the submitted item last, then the active ones by updated_at so that
    # the most recently updated one is next to last
    [item1, item2, item3] = PartAttemptCleaner.sort(items)

    assert item1.id == 3
    assert item2.id == 1
    assert item3.id == 2
  end

  test "the sort with all active" do
    items = [
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-03 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-02 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]}
    ]

    # We expect the most recently updated item to be last
    [item1, item2, item3] = PartAttemptCleaner.sort(items)

    assert item1.id == 4
    assert item2.id == 3
    assert item3.id == 2
  end

  test "the sort with all active, identical date times" do
    items = [
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]}
    ]

    # Since all records are exactly identical in state and updated_at, we expect then the
    # one first inserted to be last (the one with the lowest id)
    [item1, item2, item3] = PartAttemptCleaner.sort(items)

    assert item1.id == 2
    assert item2.id == 3
    assert item3.id == 4
  end

  test "the determination picks all active to delete" do
    part_attempts = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 3, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 4, part_id: "2", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 5, part_id: "2", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{
        id: 6,
        part_id: "2",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      },
      %{
        id: 7,
        part_id: "3",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      }
    ]

    {:ok, ids} = PartAttemptCleaner.determine_which_to_delete(part_attempts)

    assert [2, 3, 4, 5] = Enum.sort(ids)
  end

  test "the determination selects none when there is only one record per part" do
    part_attempts = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      },
      %{id: 4, part_id: "2", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{
        id: 7,
        part_id: "3",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      }
    ]

    {:ok, ids} = PartAttemptCleaner.determine_which_to_delete(part_attempts)

    assert Enum.count(ids) == 0
  end

  test "the determination selects all active when more than one non-active exists" do
    part_attempts = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :evaluated,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{
        id: 7,
        part_id: "1",
        lifecycle_state: :submitted,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      }
    ]

    {:ok, ids} = PartAttemptCleaner.determine_which_to_delete(part_attempts)

    assert [2, 4, 7] = Enum.sort(ids)
  end

  test "the determination leaves one attempt when all are active and identical" do
    part_attempts = [
      %{
        id: 1,
        part_id: "1",
        lifecycle_state: :active,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      },
      %{id: 2, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{id: 4, part_id: "1", lifecycle_state: :active, updated_at: ~U[2021-01-01 00:00:00.000Z]},
      %{
        id: 7,
        part_id: "1",
        lifecycle_state: :active,
        updated_at: ~U[2021-01-01 00:00:00.000Z]
      }
    ]

    {:ok, ids} = PartAttemptCleaner.determine_which_to_delete(part_attempts)

    assert [1, 2, 4] = Enum.sort(ids)
  end
end
