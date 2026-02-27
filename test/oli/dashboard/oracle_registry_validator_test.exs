defmodule Oli.Dashboard.OracleRegistryValidatorTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.OracleRegistry.Validator
  alias Oli.Dashboard.TestOracles.CycleA
  alias Oli.Dashboard.TestOracles.CycleB
  alias Oli.Dashboard.TestOracles.DependentA
  alias Oli.Dashboard.TestOracles.DependentB
  alias Oli.Dashboard.TestOracles.Independent
  alias Oli.Dashboard.TestOracles.InvalidKey
  alias Oli.Dashboard.TestOracles.InvalidRequires
  alias Oli.Dashboard.TestOracles.Prerequisite

  describe "validate!/1" do
    test "passes for valid registry declarations" do
      assert :ok = Validator.validate!(valid_registry())
      assert :ok = Validator.validate_on_startup!(valid_registry())
    end

    test "fails when consumer profile references undeclared oracles" do
      registry =
        put_in(valid_registry(), [:consumers, :progress_summary, :required], [:oracle_missing])

      assert_raise ArgumentError, ~r/undeclared_oracle/, fn ->
        Validator.validate!(registry)
      end
    end

    test "fails when mapped module key callback mismatches registry oracle key" do
      registry = put_in(valid_registry(), [:oracles, :oracle_independent], InvalidKey)

      assert_raise ArgumentError, ~r/oracle_key_mismatch/, fn ->
        Validator.validate!(registry)
      end
    end

    test "fails when oracle requires undeclared prerequisites" do
      registry =
        put_in(valid_registry(), [:oracles], %{
          oracle_prereq: Prerequisite,
          oracle_dep_a: DependentA,
          oracle_dep_b: DependentB,
          oracle_independent: Independent,
          oracle_invalid_requires: InvalidRequires
        })
        |> put_in([:consumers, :progress_summary, :optional], [:oracle_invalid_requires])

      assert_raise ArgumentError, ~r/undeclared_oracle/, fn ->
        Validator.validate!(registry)
      end
    end

    test "fails when execution plans contain dependency cycles" do
      registry = cyclic_registry()

      assert_raise ArgumentError, ~r/oracle_dependency_cycle/, fn ->
        Validator.validate!(registry)
      end
    end
  end

  describe "validate_profile!/2" do
    test "passes for valid profiles and fails for unknown consumers" do
      assert :ok = Validator.validate_profile!(valid_registry(), :progress_summary)

      assert_raise ArgumentError, ~r/unknown_consumer/, fn ->
        Validator.validate_profile!(valid_registry(), :missing_consumer)
      end
    end
  end

  defp valid_registry do
    %{
      consumers: %{
        progress_summary: %{
          required: [:oracle_dep_a, :oracle_dep_b],
          optional: [:oracle_independent]
        },
        support_summary: %{required: [:oracle_dep_a], optional: []}
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
