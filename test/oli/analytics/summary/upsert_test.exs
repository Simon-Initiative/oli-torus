defmodule Oli.Analytics.Summary.UpsertTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary
  alias Oli.Analytics.Common.Pipeline
  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Analytics.Summary.{
    AttemptGroup,
    ResourceSummary,
    ResponseSummary,
    ResourcePartResponse,
    StudentResponse
  }

  @reusable_model %{
    "choices" => [
      %{"id" => "1", "content" => %{}},
      %{"id" => "2", "content" => %{}},
      %{"id" => "3", "content" => %{}},
      %{"id" => "4", "content" => %{}},
      %{"id" => "5", "content" => %{}},
      %{"id" => "6", "content" => %{}}
    ],
    "inputs" => [
      %{"id" => "1", "partId" => "part1", "inputType" => "text"},
      %{"id" => "2", "partId" => "part2", "inputType" => "numeric"},
      %{
        "id" => "3",
        "partId" => "part3",
        "inputType" => "dropdown",
        "choiceIds" => ["3", "4", "6"]
      }
    ],
    "authoring" => %{
      "parts" => [
        %{"id" => "part1", "content" => %{}},
        %{"id" => "part2", "content" => %{}},
        %{"id" => "part3", "content" => %{}}
      ]
    }
  }

  describe "v2 summary upserts" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_objective("objective two", :o2)
        |> Seeder.add_activity(%{title: "one", content: %{}}, :a1)
        |> Seeder.add_activity(%{title: "two", content: %{}}, :a2)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.create_section_resources(map)
    end

    test "resource summary upserts", %{
      user1: user1,
      user2: user2,
      section: section,
      a1: a1,
      a2: a2,
      page1: page1,
      page2: page2,
      project: project,
      publication: pub
    } do
      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{analytics_version: :v2})

      context = %Context{
        user_id: user1.id,
        host_name: "localhost",
        section_id: section.id,
        project_id: project.id,
        publication_id: pub.id
      }

      # Have a student answer the question part two times, verifying that we have the
      # correct number of records and that they get incremented correctly
      short_answer(context, page1.id, a1.resource.id, "i have no idea", true)
      all = Oli.Repo.all(ResourceSummary)
      assert Enum.count(all) == 6
      assert Enum.all?(all, fn summary -> summary.num_correct == 1 end)
      assert Enum.all?(all, fn summary -> summary.num_attempts == 1 end)
      all_responses = Oli.Repo.all(ResponseSummary)
      assert Enum.count(all_responses) == 2
      assert Enum.all?(all_responses, fn summary -> summary.count == 1 end)

      short_answer(context, page1.id, a1.resource.id, "ah, now i get it", true)
      all = Oli.Repo.all(ResourceSummary)
      assert Enum.count(all) == 6
      assert Enum.all?(all, fn summary -> summary.num_correct == 2 end)
      assert Enum.all?(all, fn summary -> summary.num_attempts == 2 end)
      all_responses = Oli.Repo.all(ResponseSummary)
      assert Enum.count(all_responses) == 4
      assert Enum.all?(all_responses, fn summary -> summary.count == 1 end)

      # there should be two unique responses
      response_parts = Oli.Repo.all(ResourcePartResponse)
      assert Enum.count(response_parts) == 2
      assert Enum.any?(response_parts, fn response -> response.response == "i have no idea" end)
      assert Enum.any?(response_parts, fn response -> response.response == "ah, now i get it" end)

      # Verify that the student is associated with each of these responses
      resource_part_response_ids =
        Enum.map(response_parts, fn response -> response.id end) |> MapSet.new()

      student_responses = Oli.Repo.all(StudentResponse)

      assert Enum.count(student_responses) == 2

      assert Enum.all?(student_responses, fn sr ->
               sr.user_id == user1.id and
                 sr.section_id == section.id and
                 sr.page_id == page1.id and
                 MapSet.member?(resource_part_response_ids, sr.resource_part_response_id)
             end)

      # Now have a different student answer the question and verify we only create
      # the new records that are specific to this user
      context = %Context{
        user_id: user2.id,
        host_name: "localhost",
        section_id: section.id,
        project_id: project.id,
        publication_id: pub.id
      }

      short_answer(context, page1.id, a1.resource.id, "i have no idea", true)

      all = Oli.Repo.all(ResourceSummary)
      assert Enum.count(all) == 8

      # there should STILL be only two unique responses (across 8 total scope records),
      # but the count on one of them is incremented
      all_responses = Oli.Repo.all(ResponseSummary)
      assert Enum.count(all_responses) == 4
      assert Enum.filter(all_responses, fn summary -> summary.count == 1 end) |> Enum.count() == 2
      assert Enum.filter(all_responses, fn summary -> summary.count == 2 end) |> Enum.count() == 2

      response_parts = Oli.Repo.all(ResourcePartResponse)
      assert Enum.count(response_parts) == 2
      assert Enum.any?(response_parts, fn response -> response.response == "i have no idea" end)
      assert Enum.any?(response_parts, fn response -> response.response == "ah, now i get it" end)

      # Verify that the student is associated with each of these responses
      resource_part_response_ids =
        Enum.map(response_parts, fn response -> response.id end) |> MapSet.new()

      student_responses = Oli.Repo.all(StudentResponse)

      assert Enum.count(student_responses) == 3

      assert Enum.all?(student_responses, fn sr ->
               (sr.user_id == user1.id or sr.user_id == user2.id) and
                 sr.section_id == section.id and
                 sr.page_id == page1.id and
                 MapSet.member?(resource_part_response_ids, sr.resource_part_response_id)
             end)

      # Now have a student answer 2 activities from page 2
      two_short_answers(
        context,
        page2.id,
        a1.resource.id,
        "i think i do not know",
        true,
        a2.resource.id,
        "i am sure i am correct",
        true
      )

      # and verify the recorded response corresponds to the correct activities

      response_parts = Oli.Repo.all(ResourcePartResponse)

      activity_1_part_response =
        Enum.find(response_parts, fn response -> response.part_id == "part2" end)

      activity_2_part_response =
        Enum.find(response_parts, fn response -> response.part_id == "part3" end)

      assert activity_1_part_response.response == "i think i do not know"
      assert activity_1_part_response.label == "i think i do not know"
      assert activity_1_part_response.resource_id == a1.resource.id
      assert activity_2_part_response.response == "i am sure i am correct"
      assert activity_2_part_response.label == "i am sure i am correct"
      assert activity_2_part_response.resource_id == a2.resource.id
    end
  end

  defp short_answer(context, page_id, activity_id, response, correct) do
    registered_activities =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn activity_registration, map ->
        Map.put(map, activity_registration.slug, activity_registration)
      end)

    group = %AttemptGroup{
      context: context,
      part_attempts: [
        %{
          part_id: "part1",
          response: %{"input" => response},
          score:
            if correct do
              1
            else
              0
            end,
          lifecycle_state: :evaluated,
          out_of: 1,
          activity_revision: %{
            objectives: %{},
            content: @reusable_model,
            resource_id: activity_id,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          },
          hints: [],
          attempt_number: 1,
          activity_attempt: %{
            attempt_number: 1,
            resource_id: activity_id,
            revision_id: 1,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          }
        }
      ],
      activity_attempts: [],
      resource_attempt: %{resource_id: page_id}
    }

    Pipeline.init("test")
    |> Map.put(:data, group)
    |> Summary.upsert_resource_summaries()
    |> Summary.upsert_response_summaries()
  end

  defp two_short_answers(
         context,
         page_id,
         activity_id_1,
         response_1,
         correct_1,
         activity_id_2,
         response_2,
         correct_2
       ) do
    registered_activities =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn activity_registration, map ->
        Map.put(map, activity_registration.slug, activity_registration)
      end)

    group = %AttemptGroup{
      context: context,
      part_attempts: [
        %{
          part_id: "part2",
          response: %{"input" => response_1},
          score:
            if correct_1 do
              1
            else
              0
            end,
          lifecycle_state: :evaluated,
          out_of: 1,
          activity_revision: %{
            objectives: %{},
            content: @reusable_model,
            resource_id: activity_id_1,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          },
          hints: [],
          attempt_number: 1,
          activity_attempt: %{
            attempt_number: 1,
            resource_id: activity_id_1,
            revision_id: 1,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          }
        },
        %{
          part_id: "part3",
          response: %{"input" => response_2},
          score:
            if correct_2 do
              1
            else
              0
            end,
          lifecycle_state: :evaluated,
          out_of: 1,
          activity_revision: %{
            objectives: %{},
            content: @reusable_model,
            resource_id: activity_id_2,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          },
          hints: [],
          attempt_number: 1,
          activity_attempt: %{
            attempt_number: 1,
            resource_id: activity_id_2,
            revision_id: 2,
            activity_type_id: Map.get(registered_activities, "oli_short_answer").id
          }
        }
      ],
      activity_attempts: [],
      resource_attempt: %{resource_id: page_id}
    }

    Pipeline.init("test")
    |> Map.put(:data, group)
    |> Summary.upsert_resource_summaries()
    |> Summary.upsert_response_summaries()
  end
end
