defmodule Oli.InstructorDashboard.OracleRegistryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.TestSupport.NonInstructorRegistry
  alias Oli.InstructorDashboard.OracleRegistry
  alias Oli.InstructorDashboard.Oracles.Grades
  alias Oli.InstructorDashboard.Oracles.ProgressBins
  alias Oli.InstructorDashboard.Oracles.Placeholder.Progress
  alias Oli.InstructorDashboard.Oracles.ProgressProficiency
  alias Oli.InstructorDashboard.Oracles.StudentInfo

  describe "registry wrapper APIs" do
    test "returns deterministic known consumers" do
      assert [
               :challenging_objectives,
               :legacy_section_analytics,
               :progress_summary,
               :support_summary
             ] =
               OracleRegistry.known_consumers()
    end

    test "resolves dependency profiles for known consumer keys" do
      assert {:ok,
              %{
                required: [:oracle_instructor_progress],
                optional: [:oracle_instructor_engagement]
              }} =
               OracleRegistry.dependencies_for(:progress_summary)

      assert {:ok,
              [
                :oracle_instructor_progress_proficiency,
                :oracle_instructor_student_info
              ]} = OracleRegistry.required_for(:support_summary)

      assert {:ok, []} = OracleRegistry.optional_for(:support_summary)

      assert {:ok,
              %{
                required: [
                  :oracle_instructor_objectives_proficiency,
                  :oracle_instructor_scope_resources
                ],
                optional: []
              }} = OracleRegistry.dependencies_for(:challenging_objectives)
    end

    test "resolves oracle modules for known keys" do
      assert {:ok, Progress} = OracleRegistry.oracle_module(:oracle_instructor_progress)
      assert {:ok, ProgressBins} = OracleRegistry.oracle_module(:oracle_instructor_progress_bins)

      assert {:ok, ProgressProficiency} =
               OracleRegistry.oracle_module(:oracle_instructor_progress_proficiency)

      assert {:ok, StudentInfo} = OracleRegistry.oracle_module(:oracle_instructor_student_info)

      assert {:ok, Grades} = OracleRegistry.oracle_module(:oracle_instructor_grades)
    end

    test "returns deterministic errors for unknown keys" do
      assert {:error, {:unknown_consumer, :missing_consumer}} =
               OracleRegistry.dependencies_for(:missing_consumer)

      assert {:error, {:unknown_oracle, :missing_oracle}} =
               OracleRegistry.oracle_module(:missing_oracle)
    end

    test "builds execution plans that respect oracle prerequisites" do
      assert {:ok,
              [
                [
                  :oracle_instructor_progress_proficiency,
                  :oracle_instructor_student_info
                ]
              ]} =
               OracleRegistry.execution_plan_for([
                 :oracle_instructor_progress_proficiency,
                 :oracle_instructor_student_info
               ])
    end

    test "exposes startup bootstrap validation path" do
      assert :ok = OracleRegistry.bootstrap_validate!()
    end
  end

  describe "shared boundary compatibility" do
    # @ac "AC-007"
    test "non-instructor registries can use shared contracts unchanged" do
      assert {:ok, %{required: [:oracle_dep_a], optional: []}} =
               NonInstructorRegistry.dependencies_for(:analytics_overview)

      assert {:ok, [[:oracle_prereq], [:oracle_dep_a]]} =
               NonInstructorRegistry.execution_plan_for([:oracle_dep_a])
    end
  end
end
