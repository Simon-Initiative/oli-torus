defmodule OliWeb.Delivery.Surveys.SurveysAssessmentsTableModelTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Delivery.Surveys.SurveysAssessmentsTableModel

  describe "new/4" do
    test "creates a table model with correct columns and data" do
      assessments = [
        %{
          id: 1,
          resource_id: 100,
          title: "Survey 1",
          container_label: nil
        }
      ]

      target = :target
      students = []
      activity_types_map = %{}

      {:ok, model} =
        SurveysAssessmentsTableModel.new(assessments, target, students, activity_types_map)

      assert length(model.column_specs) == 2
      assert Enum.any?(model.column_specs, &(&1.name == :title))
      assert model.rows == assessments
      assert model.data.expandable_rows == true
      assert model.data.view_type == :surveys_instructor_dashboard
      assert model.data.target == target
      assert model.data.students == students
      assert model.data.activity_types_map == activity_types_map
    end
  end
end
