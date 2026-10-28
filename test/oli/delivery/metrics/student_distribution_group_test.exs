defmodule Oli.Delivery.Metrics.StudentDistributionGroupTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Metrics.StudentDistributionGroup

  describe "group_for/2" do
    test "activity completion below 50% is always limited_activity, regardless of proficiency" do
      assert StudentDistributionGroup.group_for(0.0, 0.49) == :limited_activity
      assert StudentDistributionGroup.group_for(0.5, 0.49) == :limited_activity
      assert StudentDistributionGroup.group_for(1.0, 0.0) == :limited_activity
      assert StudentDistributionGroup.group_for(nil, 0.49) == :limited_activity
    end

    test "activity completion at exactly 50% is high activity, not limited_activity" do
      refute StudentDistributionGroup.group_for(0.6, 0.5) == :limited_activity
      refute StudentDistributionGroup.group_for(0.2, 0.5) == :limited_activity
    end

    test "high activity and proficiency below 50% is needs_support" do
      assert StudentDistributionGroup.group_for(0.0, 0.5) == :needs_support
      assert StudentDistributionGroup.group_for(0.49, 1.0) == :needs_support
    end

    test "high activity and proficiency at or above 50% is excelling" do
      assert StudentDistributionGroup.group_for(0.5, 0.5) == :excelling
      assert StudentDistributionGroup.group_for(1.0, 1.0) == :excelling
    end

    test "nil proficiency with high activity defaults to needs_support, never raises" do
      assert StudentDistributionGroup.group_for(nil, 1.0) == :needs_support
    end
  end

  describe "assign/1" do
    test "every student resolves to exactly one group" do
      students = [
        %{id: 1, proficiency: 0.0, activities_attempted_count: 5, total_related_activities: 10},
        %{id: 2, proficiency: 0.9, activities_attempted_count: 9, total_related_activities: 10},
        %{id: 3, proficiency: 0.9, activities_attempted_count: 1, total_related_activities: 10},
        %{id: 4, proficiency: nil, activities_attempted_count: 0, total_related_activities: 0}
      ]

      groups =
        students
        |> StudentDistributionGroup.assign()
        |> Enum.map(& &1.distribution_group)

      assert groups == [:needs_support, :excelling, :limited_activity, :limited_activity]
      assert Enum.all?(groups, &(&1 in [:needs_support, :excelling, :limited_activity]))
    end

    test "total_related_activities == 0 resolves to 0% activity completion and limited_activity" do
      [result] =
        StudentDistributionGroup.assign([
          %{id: 1, proficiency: 1.0, activities_attempted_count: 0, total_related_activities: 0}
        ])

      assert result.activity_completion == 0.0
      assert result.distribution_group == :limited_activity
    end

    test "computes activity_completion as attempted / total" do
      [result] =
        StudentDistributionGroup.assign([
          %{id: 1, proficiency: 1.0, activities_attempted_count: 3, total_related_activities: 4}
        ])

      assert result.activity_completion == 0.75
      assert result.distribution_group == :excelling
    end

    test "does not mutate other fields on the student map" do
      student = %{
        id: 1,
        full_name: "Ada Lovelace",
        proficiency: 0.42,
        proficiency_range: "Medium",
        activities_attempted_count: 2,
        total_related_activities: 4
      }

      [result] = StudentDistributionGroup.assign([student])

      assert result.id == student.id
      assert result.full_name == student.full_name
      assert result.proficiency == student.proficiency
      assert result.proficiency_range == student.proficiency_range
      assert result.activities_attempted_count == student.activities_attempted_count
      assert result.total_related_activities == student.total_related_activities
    end
  end
end
