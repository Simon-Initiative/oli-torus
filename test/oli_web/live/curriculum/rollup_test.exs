defmodule OliWeb.Curriculum.RollupTest do
  use Oli.DataCase

  alias OliWeb.Curriculum.Rollup
  alias OliWeb.Curriculum.ActivityDelta

  def merge_changes(changes, state) do
    Map.merge(state, Enum.reduce(changes, %{}, fn {k, v}, m -> Map.put(m, k, v) end))
  end

  describe "rollup state" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)

      map =
        map
        |> Seeder.add_activity(
          %{
            objectives: %{"1" => [Map.get(map, :o1).resource.id]},
            title: "one",
            max_attempts: 2,
            content: content
          },
          :activity
        )
        |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity).revision.resource_id
            }
          ]
        }
      }

      Seeder.add_page(map, attrs, :page)
      |> Seeder.create_section_resources()
    end

    test "creating, then updating a rollup", %{project: project, page: %{revision: page}} = map do
      {:ok, rollup} = Rollup.new([page], project.slug)

      assert Map.keys(rollup.page_activity_map) |> length == 1
      assert Map.get(rollup.page_activity_map, page.resource_id) |> length == 1
      assert Map.keys(rollup.activity_map) |> length == 1
      assert Map.keys(rollup.objective_map) |> length == 1

      # make a change to the page to add a new activity, then observe
      # that the rollup is updated correctly. Here we add a new activity
      # to the page - an activity that targets a different learning objective.
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map = Seeder.add_objective(map, "objective two", :o2)

      map =
        map
        |> Seeder.add_activity(
          %{
            objectives: %{"1" => [Map.get(map, :o2).resource.id]},
            title: "one",
            max_attempts: 2,
            content: content
          },
          :activity2
        )

      content = %{
        "model" => [
          %{
            "type" => "activity-reference",
            "activity_id" => Map.get(map, :activity).revision.resource_id
          },
          %{
            "type" => "activity-reference",
            "activity_id" => Map.get(map, :activity2).revision.resource_id
          }
        ]
      }

      {:ok, updated} = Oli.Resources.update_revision(page, %{content: content})

      {:ok, delta} = ActivityDelta.new(updated, page)

      rollup = Rollup.page_updated(rollup, updated, delta, project.slug)

      # After updating the rollup, we expect to now see two activities referenced
      # by the page, and now two total objectives referenced
      assert Map.keys(rollup.page_activity_map) |> length == 1
      assert Map.get(rollup.page_activity_map, page.resource_id) |> length == 2
      assert Map.keys(rollup.activity_map) |> length == 2
      assert Map.keys(rollup.objective_map) |> length == 2
    end
  end
end
