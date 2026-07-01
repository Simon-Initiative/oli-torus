defmodule Oli.InstructorDashboard.Email.SituationTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.Situation

  @expected_keys [
    :struggling_students,
    :active_students_on_track,
    :excelling_students,
    :inactive_students,
    :incomplete_assessment,
    :low_proficiency_objectives,
    :beginning_course
  ]

  describe "all_keys/0" do
    test "returns the closed list of supported situation keys" do
      assert Situation.all_keys() == @expected_keys
    end

    test "always returns the same list on repeated calls" do
      assert Situation.all_keys() == Situation.all_keys()
    end
  end

  describe "description/1" do
    test "returns canonical description for :struggling_students" do
      assert Situation.description(:struggling_students) ==
               "Students showing progress or proficiency below 40%"
    end

    test "returns canonical description for :active_students_on_track" do
      assert Situation.description(:active_students_on_track) ==
               "Students with progress ≥ 40% and proficiency ≥ 40%"
    end

    test "returns canonical description for :excelling_students" do
      assert Situation.description(:excelling_students) ==
               "Students with both progress ≥ 80% and proficiency ≥ 80%"
    end

    test "returns canonical description for :inactive_students" do
      assert Situation.description(:inactive_students) ==
               "Students with no recorded activity in the last 7 days"
    end

    test "returns canonical description for :incomplete_assessment" do
      assert Situation.description(:incomplete_assessment) ==
               "Students who have not completed an assessment"
    end

    test "returns canonical description for :low_proficiency_objectives" do
      assert Situation.description(:low_proficiency_objectives) ==
               "Students with learning objectives at ≤ 40% proficiency"
    end

    test "returns canonical description for :beginning_course" do
      assert Situation.description(:beginning_course) ==
               "Course context with insufficient student data for specific recommendations"
    end

    test "raises FunctionClauseError for unsupported atom keys" do
      assert_raise FunctionClauseError, fn -> Situation.description(:unknown_key) end
    end

    test "raises FunctionClauseError for non-atom inputs" do
      assert_raise FunctionClauseError, fn -> Situation.description("struggling_students") end
    end
  end

  describe "valid?/1" do
    test "returns true for every key in the whitelist" do
      for key <- @expected_keys do
        assert Situation.valid?(key), "expected #{inspect(key)} to be valid"
      end
    end

    test "returns false for atoms not in the whitelist" do
      refute Situation.valid?(:unknown_key)
      refute Situation.valid?(:struggling)
      refute Situation.valid?(nil)
    end

    test "returns false for non-atom inputs" do
      refute Situation.valid?("struggling_students")
      refute Situation.valid?(42)
      refute Situation.valid?(%{})
      refute Situation.valid?(["a", "b"])
    end
  end
end
