defmodule OliWeb.Delivery.ScoredActivities.ActivitiesTableModelTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Delivery.ScoredActivities.ActivitiesTableModel

  describe "new/1" do
    test "creates a table model with correct columns" do
      activities = [
        %{
          resource_id: 1,
          title: "Q1",
          content: %{},
          objectives: [],
          avg_score: 0.5,
          total_attempts: 3
        }
      ]

      {:ok, model} = ActivitiesTableModel.new(activities)
      assert length(model.column_specs) == 4
      assert Enum.any?(model.column_specs, &(&1.name == :title))
      assert Enum.any?(model.column_specs, &(&1.name == :learning_objectives))
      assert Enum.any?(model.column_specs, &(&1.name == :avg_score))
      assert Enum.any?(model.column_specs, &(&1.name == :total_attempts))
      assert model.rows == activities
    end
  end
end
