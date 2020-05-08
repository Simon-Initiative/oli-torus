defmodule Oli.Delivery.Page.ActivityContextTest do

  use Oli.DataCase

  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Activities
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts

  describe "activity context" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => 1, "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{ content: content}, :publication, :project, :author, :resource_a, :a1)
      |> Seeder.add_activity(%{ content: %{ "stem" => "2"}}, :publication, :project, :author, :resource_a, :a2)
      |> Seeder.add_activity(%{ content: %{ "stem" => "3"}}, :publication, :project, :author, :resource_a, :a3)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :resource_a, :a1, :attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :attempt1, :part1_attempt1)

    end

    test "create_context_map/2 returns the activities mapped correctly", %{user1: user, a1: a1, a2: a2, a3: a3, section: section} do

      registrations = Activities.list_activity_registrations()
      resource_ids = [a1.resource_id, a2.resource_id, a3.resource_id]

      revisions = Map.put(%{}, a1.resource_id, a1)
      |> Map.put(a2.resource_id, a2)
      |> Map.put(a3.resource_id, a3)

      attempts = Attempts.get_latest_attempts([a1.resource_id, a2.resource_id, a3.resource_id], section.context_id, user.id)

      m = ActivityContext.create_context_map(resource_ids, revisions, registrations, attempts)

      assert length(Map.keys(m)) == 3
      assert Map.get(m, a1.resource_id).slug == a1.slug
      assert Map.get(m, a1.resource_id).model == "{&quot;stem&quot;:&quot;1&quot;}"
      assert Map.get(m, a1.resource_id).delivery_element == "oli-multiple-choice-delivery"
      assert Map.get(m, a1.resource_id).script == "oli_multiple_choice_delivery.js"
      assert Map.get(m, a2.resource_id).state == "{&quot;attemptNumber&quot;:1,&quot;dateEvaluated&quot;:null,&quot;hasMoreAttempts&quot;:true,&quot;outOf&quot;:null,&quot;parts&quot;:[],&quot;score&quot;:null}"
      assert Map.get(m, a2.resource_id).slug == a2.slug
      assert Map.get(m, a3.resource_id).slug == a3.slug

    end

  end


end
