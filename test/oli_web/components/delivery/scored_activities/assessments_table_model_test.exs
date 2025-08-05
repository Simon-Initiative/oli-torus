defmodule OliWeb.Delivery.ScoredActivities.AssessmentsTableModelTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Delivery.ScoredActivities.AssessmentsTableModel

  describe "new/3" do
    test "creates a table model with correct columns and data" do
      assessments = [
        %{
          id: 1,
          order: 1,
          title: "A1",
          container_label: nil,
          end_date: ~N[2024-01-01 12:00:00],
          scheduling_type: :due_by,
          avg_score: 0.5,
          total_attempts: 2,
          students_completion: 0.7,
          batch_scoring: false
        }
      ]

      ctx = %{user: %{id: 1}}
      target = :target
      {:ok, model} = AssessmentsTableModel.new(assessments, ctx, target)
      assert length(model.column_specs) == 6
      assert Enum.any?(model.column_specs, &(&1.name == :order))
      assert Enum.any?(model.column_specs, &(&1.name == :title))
      assert Enum.any?(model.column_specs, &(&1.name == :due_date))
      assert Enum.any?(model.column_specs, &(&1.name == :avg_score))
      assert Enum.any?(model.column_specs, &(&1.name == :total_attempts))
      assert Enum.any?(model.column_specs, &(&1.name == :students_completion))
      assert model.rows == assessments
    end
  end
end
