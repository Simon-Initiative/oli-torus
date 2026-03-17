defmodule Oli.Dashboard.OracleContractTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.ContractOracles.Dependent
  alias Oli.Dashboard.ContractOracles.Prerequisite
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.OracleRegistry

  describe "oracle callback conformance" do
    # @ac "AC-009"
    test "contract oracles implement required behavior callbacks" do
      assert {:module, Prerequisite} = Code.ensure_loaded(Prerequisite)
      assert {:module, Dependent} = Code.ensure_loaded(Dependent)

      assert function_exported?(Prerequisite, :key, 0)
      assert function_exported?(Prerequisite, :version, 0)
      assert function_exported?(Prerequisite, :load, 2)
      assert function_exported?(Dependent, :key, 0)
      assert function_exported?(Dependent, :version, 0)
      assert function_exported?(Dependent, :requires, 0)
      assert function_exported?(Dependent, :load, 2)
    end
  end

  describe "prerequisite planning and input injection contract" do
    # @ac "AC-008"
    test "planner stages prerequisites before dependents" do
      assert {:ok, [[:oracle_contract_prerequisite], [:oracle_contract_dependent]]} =
               OracleRegistry.execution_plan_for(contract_registry(), [:oracle_contract_dependent])
    end

    test "dependent oracle reads injected prerequisite inputs through load/2 opts" do
      {:ok, context} =
        OracleContext.new(%{
          dashboard_context_type: :section,
          dashboard_context_id: 99,
          user_id: 101,
          scope: %{container_type: :course}
        })

      assert {:ok, prerequisite_payload} = Prerequisite.load(context, [])

      assert {:ok, %{dependent_value: "uses_ready"}} =
               Dependent.load(context,
                 inputs: %{oracle_contract_prerequisite: prerequisite_payload}
               )

      assert {:error, {:missing_prerequisite_input, :oracle_contract_prerequisite}} =
               Dependent.load(context, inputs: %{})
    end
  end

  defp contract_registry do
    %{
      consumers: %{
        contract_consumer: %{required: [:oracle_contract_dependent], optional: []}
      },
      oracles: %{
        oracle_contract_prerequisite: Prerequisite,
        oracle_contract_dependent: Dependent
      }
    }
  end
end
