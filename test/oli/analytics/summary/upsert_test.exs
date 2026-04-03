defmodule Oli.Analytics.Summary.UpsertTest do
  use Oli.DataCase

  alias Oli.Analytics.Summary
  alias Oli.Analytics.Common.Pipeline
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Activities

  alias Oli.Analytics.Summary.{
    AttemptGroup,
    ResourceSummary,
    ResponseSummary,
    ResourcePartResponse,
    StudentResponse
  }

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}

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

    test "rebuild_adaptive_response_summaries_for_activity repairs only the targeted adaptive activity",
         _ctx do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)
      Seeder.create_section_resources(map)

      adaptive_registration = Activities.get_registration_by_slug("oli_adaptive")

      map =
        Seeder.add_activity(
          map,
          %{
            title: "Adaptive Summary Activity",
            activity_type_id: adaptive_registration.id,
            content: %{
              "partsLayout" => [
                %{
                  "id" => "janus_mcq-1",
                  "type" => "janus-mcq",
                  "custom" => %{
                    "mcqItems" => [
                      %{"nodes" => [%{"text" => "Option 1"}]},
                      %{"nodes" => [%{"text" => "Option 2"}]}
                    ]
                  }
                }
              ]
            }
          },
          :adaptive
        )

      section = map.section
      page1 = map.page1
      page1_revision = map.revision1
      project = map.project
      adaptive = map.adaptive

      user1_attempt =
        insert_adaptive_summary_attempt(
          section,
          page1,
          page1_revision,
          adaptive,
          map.user1,
          1,
          "Option 1"
        )

      _user2_attempt =
        insert_adaptive_summary_attempt(
          section,
          page1,
          page1_revision,
          adaptive,
          map.user2,
          2,
          "Option 2"
        )

      legacy_rpr =
        Repo.insert!(%ResourcePartResponse{
          resource_id: adaptive.resource.id,
          part_id: "janus_mcq-1",
          response: "unsupported",
          label: "unsupported"
        })

      Repo.insert!(%ResponseSummary{
        project_id: -1,
        section_id: section.id,
        page_id: page1.id,
        activity_id: adaptive.resource.id,
        resource_part_response_id: legacy_rpr.id,
        part_id: "janus_mcq-1",
        count: 2
      })

      Repo.insert!(%ResponseSummary{
        project_id: project.id,
        section_id: -1,
        page_id: page1.id,
        activity_id: adaptive.resource.id,
        resource_part_response_id: legacy_rpr.id,
        part_id: "janus_mcq-1",
        count: 2
      })

      Repo.insert!(%StudentResponse{
        section_id: section.id,
        page_id: page1.id,
        user_id: map.user1.id,
        resource_part_response_id: legacy_rpr.id
      })

      Repo.insert!(%StudentResponse{
        section_id: section.id,
        page_id: page1.id,
        user_id: map.user2.id,
        resource_part_response_id: legacy_rpr.id
      })

      activity_resource_id = adaptive.resource.id

      assert Summary.adaptive_response_summaries_stale?(activity_resource_id)

      assert {:ok, ^activity_resource_id} =
               Summary.rebuild_adaptive_response_summaries_for_activity(activity_resource_id)

      refute Summary.adaptive_response_summaries_stale?(activity_resource_id)

      refute Repo.get(ResourcePartResponse, legacy_rpr.id)

      rebuilt_responses =
        from(rpr in ResourcePartResponse,
          where: rpr.resource_id == ^adaptive.resource.id,
          order_by: [asc: rpr.response]
        )
        |> Repo.all()

      assert [
               %ResourcePartResponse{response: "1", label: "Option 1"} = response_1,
               %ResourcePartResponse{response: "2", label: "Option 2"} = response_2
             ] = rebuilt_responses

      section_rollups =
        from(rs in ResponseSummary,
          where:
            rs.activity_id == ^adaptive.resource.id and rs.page_id == ^page1.id and
              rs.section_id == ^section.id and rs.project_id == -1,
          order_by: [asc: rs.resource_part_response_id]
        )
        |> Repo.all()

      assert [
               %ResponseSummary{resource_part_response_id: rid_1, count: 1},
               %ResponseSummary{resource_part_response_id: rid_2, count: 1}
             ] = section_rollups

      assert Enum.sort([response_1.id, response_2.id]) == Enum.sort([rid_1, rid_2])

      project_rollups =
        from(rs in ResponseSummary,
          where:
            rs.activity_id == ^adaptive.resource.id and rs.page_id == ^page1.id and
              rs.project_id == ^project.id and rs.section_id == -1,
          select: rs.count
        )
        |> Repo.all()

      assert [1, 1] = Enum.sort(project_rollups)

      student_response_ids =
        from(sr in StudentResponse,
          where: sr.section_id == ^section.id and sr.page_id == ^page1.id,
          order_by: [asc: sr.user_id],
          select: {sr.user_id, sr.resource_part_response_id}
        )
        |> Repo.all()

      user_1_id = map.user1.id
      user_2_id = map.user2.id
      response_1_id = response_1.id
      response_2_id = response_2.id

      assert [
               {^user_1_id, ^response_1_id},
               {^user_2_id, ^response_2_id}
             ] = student_response_ids

      assert user1_attempt.response["selectedChoice"]["value"] == 1
    end

    test "rebuild_adaptive_response_summaries_for_activity rejects non-adaptive activities without deleting summaries",
         %{
           project: project,
           section: section,
           page1: page1,
           a1: a1,
           user1: user1
         } do
      legacy_rpr =
        Repo.insert!(%ResourcePartResponse{
          resource_id: a1.resource.id,
          part_id: "part1",
          response: "legacy-response",
          label: "legacy-response"
        })

      response_summary =
        Repo.insert!(%ResponseSummary{
          project_id: project.id,
          section_id: section.id,
          page_id: page1.id,
          activity_id: a1.resource.id,
          resource_part_response_id: legacy_rpr.id,
          part_id: "part1",
          count: 1
        })

      student_response =
        Repo.insert!(%StudentResponse{
          section_id: section.id,
          page_id: page1.id,
          user_id: user1.id,
          resource_part_response_id: legacy_rpr.id
        })

      assert {:error, :not_adaptive_activity} =
               Summary.rebuild_adaptive_response_summaries_for_activity(a1.resource.id)

      assert Repo.get(ResourcePartResponse, legacy_rpr.id)
      assert Repo.get(ResponseSummary, response_summary.id)
      assert Repo.get(StudentResponse, student_response.id)
    end
  end

  defp insert_adaptive_summary_attempt(
         section,
         page_resource,
         page_revision,
         adaptive,
         user,
         selected_choice,
         selected_choice_text
       ) do
    resource_access =
      Repo.insert!(%ResourceAccess{
        access_count: 1,
        user_id: user.id,
        section_id: section.id,
        resource_id: page_resource.id
      })

    resource_attempt =
      Repo.insert!(%ResourceAttempt{
        attempt_guid: UUID.uuid4(),
        attempt_number: 1,
        resource_access_id: resource_access.id,
        revision_id: page_revision.id,
        content: %{}
      })

    activity_attempt =
      Repo.insert!(%ActivityAttempt{
        attempt_guid: UUID.uuid4(),
        attempt_number: 1,
        resource_attempt_id: resource_attempt.id,
        resource_id: adaptive.resource.id,
        revision_id: adaptive.revision.id
      })

    Repo.insert!(%PartAttempt{
      attempt_guid: UUID.uuid4(),
      attempt_number: 1,
      grading_approach: :automatic,
      lifecycle_state: :evaluated,
      score: 1.0,
      out_of: 1.0,
      part_id: "janus_mcq-1",
      response: %{
        "selectedChoice" => %{
          "path" => "adaptive|stage.janus_mcq-1.selectedChoice",
          "value" => selected_choice
        },
        "selectedChoiceText" => %{
          "path" => "adaptive|stage.janus_mcq-1.selectedChoiceText",
          "value" => selected_choice_text
        },
        "selectedChoices" => %{
          "path" => "adaptive|stage.janus_mcq-1.selectedChoices",
          "value" => [selected_choice]
        },
        "selectedChoicesText" => %{
          "path" => "adaptive|stage.janus_mcq-1.selectedChoicesText",
          "value" => [selected_choice_text]
        }
      },
      activity_attempt_id: activity_attempt.id
    })
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
