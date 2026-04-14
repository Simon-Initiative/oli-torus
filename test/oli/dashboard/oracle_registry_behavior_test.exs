defmodule Oli.Dashboard.OracleRegistryBehaviorTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.OracleRegistry
  alias Oli.Dashboard.TestOracles.CycleA
  alias Oli.Dashboard.TestOracles.CycleB
  alias Oli.Dashboard.TestOracles.DependentA
  alias Oli.Dashboard.TestOracles.DependentB
  alias Oli.Dashboard.TestOracles.Independent
  alias Oli.Dashboard.TestOracles.Prerequisite

  describe "dependencies_for/2" do
    # @ac "AC-001"
    test "returns deterministic required and optional oracle keys" do
      assert {:ok, %{required: [:oracle_dep_a, :oracle_dep_b], optional: [:oracle_independent]}} =
               OracleRegistry.dependencies_for(valid_registry(), :progress_summary)
    end

    # @ac "AC-002"
    test "returns deterministic unknown consumer error" do
      assert {:error, {:unknown_consumer, :missing_consumer}} =
               OracleRegistry.dependencies_for(valid_registry(), :missing_consumer)
    end

    # @ac "AC-006"
    test "changing one consumer profile does not alter unrelated consumer dependencies" do
      extended_registry =
        put_in(
          valid_registry(),
          [:consumers, :support_summary, :required],
          [:oracle_dep_a, :oracle_independent]
        )

      assert {:ok, %{required: [:oracle_dep_a, :oracle_dep_b], optional: [:oracle_independent]}} =
               OracleRegistry.dependencies_for(extended_registry, :progress_summary)
    end
  end

  describe "required_for/2 and optional_for/2" do
    test "extract profile subsets from dependency profile" do
      assert {:ok, [:oracle_dep_a, :oracle_dep_b]} =
               OracleRegistry.required_for(valid_registry(), :progress_summary)

      assert {:ok, [:oracle_independent]} =
               OracleRegistry.optional_for(valid_registry(), :progress_summary)
    end
  end

  describe "oracle_module/2" do
    # @ac "AC-003"
    test "resolves exactly one module for a known oracle key" do
      assert {:ok, DependentA} = OracleRegistry.oracle_module(valid_registry(), :oracle_dep_a)
    end

    test "returns deterministic unknown oracle error" do
      assert {:error, {:unknown_oracle, :oracle_missing}} =
               OracleRegistry.oracle_module(valid_registry(), :oracle_missing)
    end
  end

  describe "execution_plan_for/2" do
    test "builds deterministic stages with shared prerequisite loaded once" do
      assert {:ok, [[:oracle_independent, :oracle_prereq], [:oracle_dep_a, :oracle_dep_b]]} =
               OracleRegistry.execution_plan_for(valid_registry(), [
                 :oracle_dep_b,
                 :oracle_independent,
                 :oracle_dep_a
               ])
    end

    test "returns deterministic cycle error when dependency graph is cyclic" do
      assert {:error, {:oracle_dependency_cycle, _cycle_keys}} =
               OracleRegistry.execution_plan_for(cyclic_registry(), [:oracle_cycle_a])
    end
  end

  describe "known_consumers/1" do
    test "returns deterministic consumer introspection order" do
      assert [:progress_summary, :support_summary] =
               OracleRegistry.known_consumers(valid_registry())
    end
  end

  defp valid_registry do
    %{
      consumers: %{
        support_summary: %{required: [:oracle_dep_a], optional: []},
        progress_summary: %{
          required: [:oracle_dep_b, :oracle_dep_a],
          optional: [:oracle_independent]
        }
      },
      oracles: %{
        oracle_prereq: Prerequisite,
        oracle_dep_a: DependentA,
        oracle_dep_b: DependentB,
        oracle_independent: Independent
      }
    }
  end

  defp cyclic_registry do
    %{
      consumers: %{
        cycle_consumer: %{required: [:oracle_cycle_a], optional: []}
      },
      oracles: %{
        oracle_cycle_a: CycleA,
        oracle_cycle_b: CycleB
      }
    }
  end
end
