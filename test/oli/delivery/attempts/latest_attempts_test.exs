defmodule Oli.Delivery.Attempts.LatestAttemptsTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts

  describe "retrieve latest evaluated attempts" do
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
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
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
        |> Seeder.add_activity(%{title: "one", max_attempts: 2, content: content}, :activity)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(
        map,
        %{
          title: "page1",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
        },
        :ungraded_page
      )
      |> Seeder.add_page(
        %{
          title: "page2",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
          graded: true
        },
        :graded_page
      )
      |> Seeder.create_section_resources()

      # Ungraded page ("page1" / :page1) attempts
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :evaluated},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :active},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt2
      )

      # Graded page ("page2" / :graded_page) attempts
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page,
        :graded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :evaluated},
        :activity,
        :graded_page_user1_attempt1,
        :user1_activity_attempt1
      )

      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page,
        :ra3
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :active},
        :activity,
        :ra3,
        :aa3
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page,
        :ra4
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :evaluated},
        :activity,
        :ra4,
        :aa5
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :active},
        :activity,
        :ra4,
        :aa6
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :evaluated},
        :activity,
        :ra4,
        :aa7
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :graded_page,
        :ra5
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content, lifecycle_state: :evaluated},
        :activity,
        :ra5,
        :aa8
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 2, transformed_model: content, lifecycle_state: :submitted},
        :activity,
        :ra5,
        :aa9
      )
    end

    test "properly identifies the latest non-active attempt", %{
      ungraded_page_user1_attempt1: resource_attempt1,
      ungraded_page_user1_activity_attempt1: a1,
      ra3: ra3,
      ra5: ra5,
      aa9: aa9
    } do

      # Tests the identification of evaluated attempt in the following ordering
      # orderings of activity attempts.  The * indicates with attempt it should be
      # identifying as 'latest'

      # Verifies case:
      # -Evaluated *
      # -Active
      [a] = Attempts.get_latest_non_active_activity_attempts(resource_attempt1.id)
      assert a.id == a1.id

      # Verifies the case:
      # -Active
      result = Attempts.get_latest_non_active_activity_attempts(ra3.id)
      assert Enum.count(result) == 0

      # Verifies the case:
      # -Evaluated
      # -Submitted *
      [a] = Attempts.get_latest_non_active_activity_attempts(ra5.id)
      assert a.id == aa9.id

    end

  end
end
