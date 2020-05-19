defmodule Oli.Delivery.Page.ActivityContextTest do

  use Oli.DataCase

  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts

  describe "activity context" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{ content: content}, :publication, :project, :author, :a1)
      |> Seeder.add_activity(%{ content: %{ "stem" => "2"}}, :publication, :project, :author, :a2)
      |> Seeder.add_activity(%{ content: %{ "stem" => "3"}}, :publication, :project, :author, :a3)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{ "stem" => "1"}}, :a1, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

    end

    test "create_context_map/2 returns the activities mapped correctly", %{attempt1: attempt1, a1: a1} do

      latest_attempts = Attempts.get_latest_attempts(attempt1.id)
      m = ActivityContext.create_context_map(false, latest_attempts)

      assert length(Map.keys(m)) == 1
      assert Map.get(m, a1.resource.id).model == "{&quot;stem&quot;:&quot;1&quot;}"
      assert Map.get(m, a1.resource.id).delivery_element == "oli-multiple-choice-delivery"
      assert Map.get(m, a1.resource.id).script == "oli_multiple_choice_delivery.js"

    end

  end


end
