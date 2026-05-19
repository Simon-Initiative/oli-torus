defmodule Oli.Dashboard.OracleDependencyPlannerTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.OracleDependencyPlanner

  describe "build_plan/2" do
    test "builds topological stages for fan-out with shared prerequisite" do
      resolver = fn
        :oracle_dep_a -> {:ok, [:oracle_prereq]}
        :oracle_dep_b -> {:ok, [:oracle_prereq]}
        :oracle_prereq -> {:ok, []}
      end

      assert {:ok, [[:oracle_prereq], [:oracle_dep_a, :oracle_dep_b]]} =
               OracleDependencyPlanner.build_plan([:oracle_dep_a, :oracle_dep_b], resolver)
    end

    test "rejects duplicate requested oracle keys deterministically" do
      resolver = fn _oracle_key -> {:ok, []} end

      assert {:error,
              {:invalid_dependency_profile,
               {:duplicate_oracle_keys, :requested_oracles, [:oracle_dep_a]}}} =
               OracleDependencyPlanner.build_plan([:oracle_dep_a, :oracle_dep_a], resolver)
    end

    test "rejects self dependencies deterministically" do
      resolver = fn
        :oracle_dep_a -> {:ok, [:oracle_dep_a]}
      end

      assert {:error, {:invalid_dependency_profile, {:self_dependency, :oracle_dep_a}}} =
               OracleDependencyPlanner.build_plan([:oracle_dep_a], resolver)
    end

    test "returns deterministic cycle errors" do
      resolver = fn
        :oracle_cycle_a -> {:ok, [:oracle_cycle_b]}
        :oracle_cycle_b -> {:ok, [:oracle_cycle_a]}
      end

      assert {:error, {:oracle_dependency_cycle, _cycle_keys}} =
               OracleDependencyPlanner.build_plan([:oracle_cycle_a], resolver)
    end
  end

  describe "validate_acyclic/1" do
    test "returns :ok for valid acyclic graphs" do
      graph = %{
        oracle_dep_a: [:oracle_prereq],
        oracle_dep_b: [:oracle_prereq],
        oracle_prereq: []
      }

      assert :ok = OracleDependencyPlanner.validate_acyclic(graph)
    end

    test "returns deterministic cycle errors for cyclic graphs" do
      graph = %{
        oracle_cycle_a: [:oracle_cycle_b],
        oracle_cycle_b: [:oracle_cycle_a]
      }

      assert {:error, {:oracle_dependency_cycle, _cycle_keys}} =
               OracleDependencyPlanner.validate_acyclic(graph)
    end
  end
end
