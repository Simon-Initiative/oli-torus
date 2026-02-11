defmodule OliWeb.Components.Delivery.LearningObjectives.FiltersTest do
  use ExUnit.Case, async: true

  alias OliWeb.Components.Delivery.LearningObjectives

  describe "filtered_objectives/2 and objectives_count/1" do
    test "counts only top-level outcomes and filtered low sub-objectives" do
      objectives = [
        %{
          resource_id: 1,
          title: "LO.02",
          objective: "LO.02",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          container_ids: [10]
        },
        %{
          resource_id: 2,
          title: "Sub.LO.2a",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          container_ids: [10]
        },
        %{
          resource_id: 3,
          title: "Sub.LO.2b",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2b",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Medium",
          container_ids: [10]
        },
        %{
          resource_id: 4,
          title: "Sub.LO.2c",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2c",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "High",
          container_ids: [10]
        },
        %{
          resource_id: 5,
          title: "LO.99",
          objective: "LO.99",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          container_ids: [99]
        },
        %{
          resource_id: 6,
          title: "Sub.LO.99a",
          objective: "LO.99",
          objective_resource_id: 5,
          subobjective: "Sub.LO.99a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          container_ids: [99]
        }
      ]

      params = %{
        text_search: nil,
        filter_by: 10,
        selected_proficiency_ids: [],
        selected_card_value: :low_proficiency_outcomes,
        sort_by: :objective_instructor_dashboard,
        sort_order: :asc
      }

      scoped = Enum.filter(objectives, &Enum.member?(&1.container_ids, 10))
      filtered = LearningObjectives.filtered_objectives(scoped, params)
      counts = LearningObjectives.objectives_count(filtered)

      assert length(filtered) == 4
      assert counts.low_proficiency_outcomes == 1
      assert counts.low_proficiency_skills == 1
    end

    test "module scope keeps parent rows when only subobjectives match" do
      objectives = [
        %{
          resource_id: 1,
          title: "LO.02",
          objective: "LO.02",
          subobjective: nil,
          student_proficiency_obj: "High",
          student_proficiency_subobj: nil,
          container_ids: [10]
        },
        %{
          resource_id: 2,
          title: "Sub.LO.2a",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2a",
          student_proficiency_obj: "High",
          student_proficiency_subobj: "Low",
          container_ids: [10]
        },
        %{
          resource_id: 3,
          title: "LO.99",
          objective: "LO.99",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          container_ids: [99]
        },
        %{
          resource_id: 4,
          title: "Sub.LO.99a",
          objective: "LO.99",
          objective_resource_id: 3,
          subobjective: "Sub.LO.99a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          container_ids: [99]
        }
      ]

      params = %{
        text_search: "Sub.LO.2a",
        filter_by: 10,
        selected_proficiency_ids: [],
        selected_card_value: nil,
        sort_by: :objective_instructor_dashboard,
        sort_order: :asc
      }

      scoped = Enum.filter(objectives, &Enum.member?(&1.container_ids, 10))
      filtered = LearningObjectives.filtered_objectives(scoped, params)

      assert Enum.any?(filtered, &(&1.subobjective == "Sub.LO.2a"))
      refute Enum.any?(filtered, &(&1.objective == "LO.99"))
    end
  end
end
