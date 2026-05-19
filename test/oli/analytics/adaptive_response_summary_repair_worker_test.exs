defmodule Oli.Analytics.AdaptiveResponseSummaryRepairWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Activities
  alias Oli.Analytics.AdaptiveResponseSummaryRepairWorker
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.{ResourcePartResponse, ResponseSummary, StudentResponse}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Repo

  import Ecto.Query

  test "schedules one unique repair job and repairs stale adaptive summaries" do
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

    insert_adaptive_summary_attempt(
      section,
      page1,
      page1_revision,
      adaptive,
      map.user1,
      1,
      "Option 1"
    )

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

    assert Summary.adaptive_response_summaries_stale?(adaptive.resource.id)

    assert {:ok, _} = AdaptiveResponseSummaryRepairWorker.schedule(adaptive.resource.id)
    assert {:ok, _} = AdaptiveResponseSummaryRepairWorker.schedule(adaptive.resource.id)

    assert_enqueued(
      worker: AdaptiveResponseSummaryRepairWorker,
      args: %{"activity_resource_id" => adaptive.resource.id, "repair_version" => 1}
    )

    assert [_single_job] = all_enqueued(worker: AdaptiveResponseSummaryRepairWorker)

    assert :ok =
             perform_job(AdaptiveResponseSummaryRepairWorker, %{
               "activity_resource_id" => adaptive.resource.id,
               "repair_version" => 1
             })

    refute Summary.adaptive_response_summaries_stale?(adaptive.resource.id)

    rebuilt_responses =
      from(rpr in ResourcePartResponse,
        where: rpr.resource_id == ^adaptive.resource.id,
        order_by: [asc: rpr.response],
        select: {rpr.response, rpr.label}
      )
      |> Repo.all()

    assert [{"1", "Option 1"}, {"2", "Option 2"}] = rebuilt_responses
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
        }
      },
      activity_attempt_id: activity_attempt.id
    })
  end
end
