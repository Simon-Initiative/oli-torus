defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModelTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel

  describe "instructor_dashboard confidence column gating" do
    test "omits the Confidence column when confidence is not supported" do
      {:ok, table_model} = ObjectivesTableModel.new([], :instructor_dashboard, false)

      refute Enum.any?(table_model.column_specs, &(&1.name == :confidence))
    end

    test "omits the Confidence column when the flag is not provided" do
      {:ok, table_model} = ObjectivesTableModel.new([], :instructor_dashboard)

      refute Enum.any?(table_model.column_specs, &(&1.name == :confidence))
    end

    test "includes the Confidence column, positioned between Student Proficiency and Proficiency Distribution, when supported" do
      {:ok, table_model} = ObjectivesTableModel.new([], :instructor_dashboard, true)

      names = Enum.map(table_model.column_specs, & &1.name)

      assert :confidence in names

      proficiency_index = Enum.find_index(names, &(&1 == :student_proficiency_obj))
      confidence_index = Enum.find_index(names, &(&1 == :confidence))
      distribution_index = Enum.find_index(names, &(&1 == :student_proficiency_distribution))

      assert proficiency_index < confidence_index
      assert confidence_index < distribution_index
    end
  end
end
