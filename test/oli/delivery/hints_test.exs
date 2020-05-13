defmodule Oli.Delivery.HintsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.{Hint, Part}

  describe "processing hints" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"match" => "a", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}}
            ],
            "hints" => [
              %{"id" => "h1", "content" => [%{"type" => "p", "children" => [%{"text" => "hint one"}]}]},
              %{"id" => "h2", "content" => [%{"type" => "p", "children" => [%{"text" => "hint two"}]}]},
              %{"id" => "h3", "content" => [%{"type" => "p", "children" => [%{"text" => "hint three"}]}]},
            ],
            "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :publication, :project, :author, :activity_resource, :activity_revision)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity_revision).resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource_id]}
      }

      Seeder.add_page(map, attrs, :page_resource, :page_revision)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page_resource, :page_revision, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity_resource, :activity_revision, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

    end

    test "exhaust all three hints", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      assert {:ok, %Hint{id: "h1", content: [%{"type" => "p", "children" => [%{"text" => "hint one"}]}]}, true}
        == Attempts.request_hint(activity_attempt.attempt_guid, part_attempt.attempt_guid)

      assert {:ok, %Hint{id: "h2", content: [%{"type" => "p", "children" => [%{"text" => "hint two"}]}]}, true}
        == Attempts.request_hint(activity_attempt.attempt_guid, part_attempt.attempt_guid)

      assert {:ok, %Hint{id: "h3", content: [%{"type" => "p", "children" => [%{"text" => "hint three"}]}]}, false}
        == Attempts.request_hint(activity_attempt.attempt_guid, part_attempt.attempt_guid)

      assert {:error, {:no_more_hints}}
        == Attempts.request_hint(activity_attempt.attempt_guid, part_attempt.attempt_guid)

    end

    test "verify :not_found returned when guids are not found", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      assert {:error, {:not_found}}
        == Attempts.request_hint(activity_attempt.attempt_guid, "does not exist")

      assert {:error, {:not_found}}
        == Attempts.request_hint("does not exist", part_attempt.attempt_guid)

      assert {:error, {:not_found}}
        == Attempts.request_hint("does not exist", "does not exist")

    end

  end

end
