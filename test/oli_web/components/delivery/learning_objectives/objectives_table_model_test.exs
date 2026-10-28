defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel

  defp render_confidence_cell(row) do
    {:ok, table_model} = ObjectivesTableModel.new([], :instructor_dashboard, true)
    confidence_spec = Enum.find(table_model.column_specs, &(&1.name == :confidence))

    render_component(fn assigns -> confidence_spec.render_fn.(assigns, row, confidence_spec) end)
  end

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

  describe "confidence cell rendering" do
    test "shows the top-level row's own confidence" do
      row = %{subobjective: nil, confidence_obj: "Medium", confidence_subobj: nil}

      html = render_confidence_cell(row)

      assert html =~ "Medium"
    end

    # Regression test: a sub-objective with no confidence of its own must show "-",
    # not silently inherit its parent's confidence_obj value.
    test "shows a dash for a sub-objective with no confidence of its own, instead of falling back to the parent's" do
      row = %{
        subobjective: "Some Sub-Objective",
        confidence_obj: "Medium",
        confidence_subobj: nil
      }

      html = render_confidence_cell(row)

      refute html =~ "Medium"
      assert html =~ "-"
    end

    test "shows a sub-objective's own confidence when it has one" do
      row = %{
        subobjective: "Some Sub-Objective",
        confidence_obj: "Medium",
        confidence_subobj: "High"
      }

      html = render_confidence_cell(row)

      assert html =~ "High"
      refute html =~ "Medium"
    end
  end
end
