defmodule Oli.Qa.PedagogyTest do
  use Oli.DataCase
  alias Oli.Qa.Reviewers.Pedagogy
  alias Oli.Qa.Warnings
  alias Oli.Publishing

  describe "qa pedagogy checks" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.add_objective("I love writing objectives", :o1)
        |> Seeder.add_review("pedagogy", :review)

      map
      |> Seeder.add_page(%{objectives: %{"attached" => []}}, :page_no_objectives)
      |> Seeder.add_page(
        %{objectives: %{"attached" => [Map.get(map, :o1).resource.id]}},
        :page_has_objectives
      )
      |> Seeder.add_page(
        %{
          content: %{
            "model" => [
              %{
                "activity_id" => 10,
                "children" => [],
                "id" => "3781635590",
                "purpose" => "None",
                "type" => "activity-reference"
              }
            ]
          }
        },
        :page_has_activities
      )
      |> Seeder.add_activity(%{objectives: %{}}, :activity_no_objectives)
      |> Seeder.add_activity(
        %{objectives: %{"1" => [Map.get(map, :o1).resource.id]}},
        :activity_has_objectives
      )
      |> Map.put(
        :pages,
        Publishing.get_unpublished_revisions_by_type(Map.get(map, :project).slug, "page")
      )
      |> Map.put(
        :activities,
        Publishing.get_unpublished_revisions_by_type(Map.get(map, :project).slug, "activity")
      )
    end

    test "no attached objectives", %{
      project: project,
      review: review,
      activities: activities,
      activity_no_objectives: activity_no_objectives,
      activity_has_objectives: activity_has_objectives
    } do
      Pedagogy.no_attached_objectives(review, activities)
      warnings = Warnings.list_active_warnings(project.id)

      # activities
      assert Enum.find(warnings, &(&1.revision.id == activity_no_objectives.revision.id))
      assert !Enum.find(warnings, &(&1.revision.id == activity_has_objectives.revision.id))
    end

    test "no attached activities", %{
      project: project,
      review: review,
      pages: pages,
      page_has_activities: page_has_activities,
      page_has_objectives: page_has_objectives
    } do
      Pedagogy.no_attached_activities(review, pages)
      warnings = Warnings.list_active_warnings(project.id)

      # this page has no activities attached
      assert Enum.find(warnings, &(&1.revision.id == page_has_objectives.revision.id))
      # this page has activities attached
      assert !Enum.find(warnings, &(&1.revision.id == page_has_activities.revision.id))
    end
  end
end
