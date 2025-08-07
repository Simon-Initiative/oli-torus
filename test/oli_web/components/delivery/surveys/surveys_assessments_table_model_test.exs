defmodule OliWeb.Delivery.Surveys.SurveysAssessmentsTableModelTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Delivery.Surveys.SurveysAssessmentsTableModel

  describe "new/3" do
    test "creates a table model with correct columns and data" do
      assessments = [
        %{
          id: 1,
          title: "Survey 1",
          container_label: nil,
          avg_score: 0.5,
          total_attempts: 2,
          students_completion: 0.7
        }
      ]

      ctx = %{user: %{id: 1}}
      target = :target
      {:ok, model} = SurveysAssessmentsTableModel.new(assessments, ctx, target)
      assert length(model.column_specs) == 4
      assert Enum.any?(model.column_specs, &(&1.name == :title))
      assert Enum.any?(model.column_specs, &(&1.name == :avg_score))
      assert Enum.any?(model.column_specs, &(&1.name == :total_attempts))
      assert Enum.any?(model.column_specs, &(&1.name == :students_completion))
      assert model.rows == assessments
    end
  end
end
