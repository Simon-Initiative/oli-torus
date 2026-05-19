defmodule Oli.InstructorDashboard.OracleBindingsTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.OracleBindings

  describe "bindings/0" do
    test "returns capability slot maps and oracle module map" do
      bindings = OracleBindings.bindings()

      assert Map.has_key?(bindings, :consumers)
      assert Map.has_key?(bindings, :oracles)
      assert Map.has_key?(bindings.consumers, :progress_summary)
      assert Map.has_key?(bindings.consumers, :support_summary)
      assert Map.has_key?(bindings.consumers, :assessments_summary)
      assert Map.has_key?(bindings.consumers, :summary_recommendation)
      assert Map.has_key?(bindings.consumers, :challenging_objectives)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_progress)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_progress_bins)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_schedule_position)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_progress_proficiency)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_student_info)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_scope_resources)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_grades)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_recommendation)
      assert Map.has_key?(bindings.oracles, :oracle_instructor_objectives_proficiency)
    end
  end

  describe "binding_for/1" do
    test "resolves known consumer binding" do
      assert {:ok, binding} = OracleBindings.binding_for(:progress_summary)

      assert binding.required_oracles == %{
               progress_bins: :oracle_instructor_progress_bins,
               scope_resources: :oracle_instructor_scope_resources
             }

      assert binding.optional_oracles == %{
               legacy_progress: :oracle_instructor_progress,
               schedule_position: :oracle_instructor_schedule_position
             }
    end

    test "resolves challenging objectives binding with objective-specific dependencies" do
      assert {:ok, binding} = OracleBindings.binding_for(:challenging_objectives)

      assert binding.required_oracles == %{
               objectives_proficiency: :oracle_instructor_objectives_proficiency,
               scope_resources: :oracle_instructor_scope_resources
             }

      assert binding.optional_oracles == %{}
    end

    test "resolves the assessments summary consumer binding" do
      assert {:ok, binding} = OracleBindings.binding_for(:assessments_summary)

      assert binding.required_oracles == %{
               grades: :oracle_instructor_grades,
               scope_resources: :oracle_instructor_scope_resources
             }

      assert binding.optional_oracles == %{}
    end

    test "resolves the recommendation summary consumer binding" do
      assert {:ok, binding} = OracleBindings.binding_for(:summary_recommendation)

      assert binding.required_oracles == %{
               recommendation: :oracle_instructor_recommendation
             }

      assert binding.optional_oracles == %{}
    end

    test "returns deterministic error for unknown consumers" do
      assert {:error, {:unknown_consumer, :unknown_consumer}} =
               OracleBindings.binding_for(:unknown_consumer)
    end
  end

  describe "consumer_profiles/0" do
    test "canonicalizes slot maps into deterministic required/optional lists" do
      profiles = OracleBindings.consumer_profiles()

      assert profiles.progress_summary.required == [
               :oracle_instructor_progress_bins,
               :oracle_instructor_scope_resources
             ]

      assert profiles.progress_summary.optional == [
               :oracle_instructor_progress,
               :oracle_instructor_schedule_position
             ]

      assert profiles.support_summary.required == [
               :oracle_instructor_progress_proficiency,
               :oracle_instructor_student_info
             ]

      assert profiles.support_summary.optional == []

      assert profiles.challenging_objectives.required == [
               :oracle_instructor_objectives_proficiency,
               :oracle_instructor_scope_resources
             ]

      assert profiles.challenging_objectives.optional == []

      assert profiles.assessments_summary.required == [
               :oracle_instructor_grades,
               :oracle_instructor_scope_resources
             ]

      assert profiles.assessments_summary.optional == []

      assert profiles.summary_recommendation.required == [
               :oracle_instructor_recommendation
             ]

      assert profiles.summary_recommendation.optional == []
    end

    test "extending one consumer binding does not mutate unrelated consumer profiles" do
      base_bindings = OracleBindings.bindings()

      extended_bindings =
        put_in(
          base_bindings,
          [:consumers, :progress_summary, :optional_oracles, :new_capability],
          :oracle_instructor_progress
        )

      assert get_in(base_bindings, [:consumers, :support_summary]) ==
               get_in(extended_bindings, [:consumers, :support_summary])
    end
  end
end
