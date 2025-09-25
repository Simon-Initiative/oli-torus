defmodule Oli.Delivery.Attempts.ActivityLifecycle.RollUpFixBadRecordsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp

  describe "fix_bad_records/1" do
    test "returns empty list when given empty list" do
      assert RollUp.fix_bad_records([]) == []
    end

    test "returns single record unchanged when only one record exists" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert result == records
    end

    test "returns records unchanged when no duplicates exist across different resources" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        %{
          resource_id: 2,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert result == records
    end

    test "returns records unchanged when no duplicates exist for same resource" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        %{
          resource_id: 1,
          attempt_number: 2,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-02 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert result == records
    end

    test "handles duplicate attempt numbers with one evaluated record" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :active,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      assert hd(result).lifecycle_state == :evaluated
    end

    test "handles duplicate attempt numbers with multiple evaluated records, returns most recent" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-02 12:00:00Z]
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 10:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      assert hd(result).date_evaluated == ~U[2024-01-02 12:00:00Z]
    end

    test "handles duplicate attempt numbers with no evaluated records, returns any one" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :active,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :submitted,
          date_evaluated: nil
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      assert hd(result).attempt_number == 1
      assert hd(result).resource_id == 1
    end

    test "handles multiple resources with duplicate attempt numbers" do
      records = [
        # Resource 1 duplicates
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :active,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        # Resource 2 duplicates
        %{
          resource_id: 2,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 10:00:00Z]
        },
        %{
          resource_id: 2,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-02 10:00:00Z]
        },
        # Resource 3 no duplicates
        %{
          resource_id: 3,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 3

      # Group results by resource_id for verification
      by_resource = Enum.group_by(result, & &1.resource_id)

      # Resource 1 should have the evaluated record
      resource_1_result = by_resource[1] |> hd()
      assert resource_1_result.lifecycle_state == :evaluated

      # Resource 2 should have the most recent evaluated record
      resource_2_result = by_resource[2] |> hd()
      assert resource_2_result.date_evaluated == ~U[2024-01-02 10:00:00Z]

      # Resource 3 should remain unchanged
      resource_3_result = by_resource[3] |> hd()
      assert resource_3_result.date_evaluated == ~U[2024-01-01 12:00:00Z]
    end

    test "handles complex scenario with multiple duplicates per resource" do
      records = [
        # Resource 1 - attempt 1 duplicates (2 evaluated)
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-02 12:00:00Z]
        },
        # Resource 1 - attempt 2 duplicates (no evaluated)
        %{
          resource_id: 1,
          attempt_number: 2,
          lifecycle_state: :active,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 2,
          lifecycle_state: :submitted,
          date_evaluated: nil
        },
        # Resource 1 - attempt 3 no duplicates
        %{
          resource_id: 1,
          attempt_number: 3,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-03 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 3

      sorted_result = Enum.sort_by(result, & &1.attempt_number)

      # Attempt 1 should have most recent evaluated
      attempt_1 = Enum.at(sorted_result, 0)
      assert attempt_1.attempt_number == 1
      assert attempt_1.date_evaluated == ~U[2024-01-02 12:00:00Z]

      # Attempt 2 should have any one of the non-evaluated
      attempt_2 = Enum.at(sorted_result, 1)
      assert attempt_2.attempt_number == 2
      assert attempt_2.lifecycle_state in [:active, :submitted]

      # Attempt 3 should remain unchanged
      attempt_3 = Enum.at(sorted_result, 2)
      assert attempt_3.attempt_number == 3
      assert attempt_3.lifecycle_state == :evaluated
    end

    test "preserves order of non-duplicate records" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        },
        %{
          resource_id: 2,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-02 12:00:00Z]
        },
        %{
          resource_id: 3,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-03 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert result == records
    end

    test "handles records with nil date_evaluated correctly" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: ~U[2024-01-01 12:00:00Z]
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      # Should return the one with a date_evaluated
      assert hd(result).date_evaluated == ~U[2024-01-01 12:00:00Z]
    end

    test "handles all records with nil date_evaluated" do
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :evaluated,
          date_evaluated: nil
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      assert hd(result).date_evaluated == nil
    end

    test "handles edge case with single record in list format" do
      # This tests the head function behavior
      records = [
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :active,
          date_evaluated: nil
        },
        %{
          resource_id: 1,
          attempt_number: 1,
          lifecycle_state: :submitted,
          date_evaluated: nil
        }
      ]

      result = RollUp.fix_bad_records(records)
      assert length(result) == 1
      # Should return the first one (head of the list)
      assert hd(result).lifecycle_state == :active
    end
  end
end
