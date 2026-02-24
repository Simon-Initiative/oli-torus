defmodule Oli.InstructorDashboard.DataSnapshot.DatasetRegistryTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.DatasetRegistry

  describe "datasets_for/1" do
    test "returns deterministic default profile mappings" do
      assert {:ok, default_specs} = DatasetRegistry.datasets_for(:default)
      assert {:ok, instructor_specs} = DatasetRegistry.datasets_for(:instructor_dashboard)

      assert default_specs == instructor_specs

      assert Enum.map(default_specs, &Map.fetch!(&1, :dataset_id)) == [
               :summary,
               :progress,
               :student_support,
               :challenging_objectives,
               :assessments
             ]

      assert Enum.all?(default_specs, fn spec ->
               Map.fetch!(spec, :failure_policy) == :fail_closed
             end)
    end

    test "returns optional ai dataset for with_optional_ai profile" do
      assert {:ok, specs} = DatasetRegistry.datasets_for(:with_optional_ai)

      assert Enum.map(specs, &Map.fetch!(&1, :dataset_id)) == [
               :summary,
               :progress,
               :student_support,
               :challenging_objectives,
               :assessments,
               :ai_context
             ]

      ai_spec =
        Enum.find(specs, fn spec ->
          Map.fetch!(spec, :dataset_id) == :ai_context
        end)

      assert Map.fetch!(ai_spec, :failure_policy) == :allow_partial_with_manifest
      assert Map.fetch!(ai_spec, :required_projections) == [:ai_context]
      assert Map.fetch!(ai_spec, :optional_projections) == []
    end

    test "returns deterministic unknown profile error" do
      assert {:error, {:unknown_export_profile, :missing_profile}} =
               DatasetRegistry.datasets_for(:missing_profile)
    end
  end

  describe "dataset_spec/1" do
    test "returns deterministic spec for known dataset id" do
      assert {:ok, spec} = DatasetRegistry.dataset_spec(:summary)
      assert Map.fetch!(spec, :dataset_id) == :summary
      assert Map.fetch!(spec, :filename) == "summary.csv"
      assert Map.fetch!(spec, :required_projections) == [:summary]
      assert Map.fetch!(spec, :failure_policy) == :fail_closed
    end

    test "returns deterministic unknown dataset error" do
      assert {:error, {:unknown_dataset, :missing_dataset}} =
               DatasetRegistry.dataset_spec(:missing_dataset)
    end
  end
end
