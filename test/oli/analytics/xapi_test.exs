defmodule Oli.Analytics.XAPITest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Analytics.XAPI
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Experiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint}
  alias Oli.Resources.ResourceType

  @experiment_attributions_key "http://oli.cmu.edu/extensions/experiment_attributions"

  describe "construct_bundle/2 video experiment attributions" do
    test "attaches media interaction attributions when video is in the assigned alternatives branch" do
      %{
        user: user,
        resource_attempt: resource_attempt,
        experiment: experiment,
        assignment: assignment
      } = setup_video_experiment_context()

      {:ok, %StatementBundle{} = bundle} =
        XAPI.construct_bundle(
          %{
            "category" => "video",
            "event_type" => "played",
            "host_name" => "http://example.edu",
            "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
            "video_url" => "https://example.edu/video.mp4",
            "video_title" => "Example video",
            "video_length" => 60,
            "video_play_time" => 0,
            "content_element_id" => "video-in-selected-branch"
          },
          user.id
        )

      attributions =
        bundle
        |> statement_from_bundle()
        |> get_in(["context", "extensions", @experiment_attributions_key])

      assert [%{"role" => "media_interaction"} = attribution] = attributions
      assert attribution["attribution_type"] == "assignment"
      assert attribution["experiment_id"] == experiment.id
      assert attribution["assignment_id"] == assignment.id
    end

    test "does not attach attributions when video is outside the assigned alternatives branch" do
      %{user: user, resource_attempt: resource_attempt} = setup_video_experiment_context()

      {:ok, %StatementBundle{} = bundle} =
        XAPI.construct_bundle(
          %{
            "category" => "video",
            "event_type" => "played",
            "host_name" => "http://example.edu",
            "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
            "video_url" => "https://example.edu/video.mp4",
            "video_title" => "Example video",
            "video_length" => 60,
            "video_play_time" => 0,
            "content_element_id" => "video-in-unselected-branch"
          },
          user.id
        )

      refute bundle
             |> statement_from_bundle()
             |> get_in(["context", "extensions", @experiment_attributions_key])
    end

    test "does not query assignments when the media element is outside alternatives" do
      %{user: user, resource_attempt: resource_attempt} = setup_video_experiment_context()
      handler_id = "media-assignment-query-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          if is_binary(metadata.query) and
               String.contains?(metadata.query, ~s["experiment_assignments"]) do
            send(parent, :assignment_query)
          end
        end,
        %{}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:ok, %StatementBundle{}} =
               XAPI.construct_bundle(
                 %{
                   "category" => "video",
                   "event_type" => "played",
                   "host_name" => "http://example.edu",
                   "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
                   "video_url" => "https://example.edu/video.mp4",
                   "video_title" => "Example video",
                   "video_length" => 60,
                   "video_play_time" => 0,
                   "content_element_id" => "not-in-alternatives"
                 },
                 user.id
               )

      refute_receive :assignment_query
    end

    test "matches media branches by condition code when the option id is absent" do
      %{user: user, resource_attempt: resource_attempt, assignment: assignment} =
        setup_video_experiment_context()

      Condition
      |> Repo.get!(assignment.condition_id)
      |> Condition.changeset(%{option_id: nil, condition_code: "alt-a"})
      |> Repo.update!()

      assert {:ok, %StatementBundle{} = bundle} =
               XAPI.construct_bundle(
                 %{
                   "category" => "video",
                   "event_type" => "played",
                   "host_name" => "http://example.edu",
                   "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
                   "video_url" => "https://example.edu/video.mp4",
                   "video_title" => "Example video",
                   "video_length" => 60,
                   "video_play_time" => 0,
                   "content_element_id" => "video-in-selected-branch"
                 },
                 user.id
               )

      assert [%{"assignment_id" => assignment_id}] =
               bundle
               |> statement_from_bundle()
               |> get_in(["context", "extensions", @experiment_attributions_key])

      assert assignment_id == assignment.id
    end

    test "returns only the assignment matching the media branch" do
      %{
        user: user,
        section: section,
        resource_attempt: resource_attempt,
        experiment: experiment,
        assignment: matching_assignment,
        scope: scope
      } = setup_video_experiment_context()

      unrelated_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_alternatives(),
          content: %{"options" => [%{"id" => "other", "name" => "Other"}]}
        )

      unrelated_decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(%{
          experiment_id: experiment.id,
          alternatives_resource_id: unrelated_revision.resource_id,
          decision_point_key: "alternatives:#{unrelated_revision.resource_id}",
          position: 1
        })
        |> Repo.insert!()

      unrelated_condition =
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: experiment.id,
          decision_point_id: unrelated_decision_point.id,
          condition_code: "other",
          option_id: "other",
          weight: 1.0,
          position: 0
        })
        |> Repo.insert!()

      %Assignment{}
      |> Assignment.changeset(%{
        experiment_id: experiment.id,
        decision_point_id: unrelated_decision_point.id,
        condition_id: unrelated_condition.id,
        section_id: section.id,
        enrollment_id: scope.enrollment_id,
        user_id: user.id,
        assigned_by_policy: "weighted_random",
        policy_version: "weighted_random:v1",
        assignment_key: "#{experiment.id}:#{unrelated_decision_point.id}:#{scope.enrollment_id}",
        assigned_at: DateTime.utc_now(),
        runtime_event_state: %{}
      })
      |> Repo.insert!()

      assert {:ok, %StatementBundle{} = bundle} =
               XAPI.construct_bundle(
                 %{
                   "category" => "video",
                   "event_type" => "played",
                   "host_name" => "http://example.edu",
                   "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
                   "video_url" => "https://example.edu/video.mp4",
                   "video_title" => "Example video",
                   "video_length" => 60,
                   "video_play_time" => 0,
                   "content_element_id" => "video-in-selected-branch"
                 },
                 user.id
               )

      assert [%{"assignment_id" => assignment_id}] =
               bundle
               |> statement_from_bundle()
               |> get_in(["context", "extensions", @experiment_attributions_key])

      assert assignment_id == matching_assignment.id
    end

    test "keeps media interaction attribution after experiment is no longer active" do
      %{
        user: user,
        resource_attempt: resource_attempt,
        experiment: experiment,
        assignment: assignment,
        scope: scope
      } = setup_video_experiment_context()

      assert {:ok, _completed} =
               Experiments.complete_experiment(experiment.id, %LifecycleRequest{scope: scope})

      {:ok, %StatementBundle{} = bundle} =
        XAPI.construct_bundle(
          %{
            "category" => "video",
            "event_type" => "played",
            "host_name" => "http://example.edu",
            "key" => %{"page_attempt_guid" => resource_attempt.attempt_guid},
            "video_url" => "https://example.edu/video.mp4",
            "video_title" => "Example video",
            "video_length" => 60,
            "video_play_time" => 0,
            "content_element_id" => "video-in-selected-branch"
          },
          user.id
        )

      assert [
               %{
                 "role" => "media_interaction",
                 "attribution_type" => "assignment",
                 "assignment_id" => assignment_id
               }
             ] =
               bundle
               |> statement_from_bundle()
               |> get_in(["context", "extensions", @experiment_attributions_key])

      assert assignment_id == assignment.id
    end

    test "attaches media interaction attributions for resource-only video events" do
      %{user: user, section: section, page_revision: page_revision, assignment: assignment} =
        setup_video_experiment_context()

      section_resource =
        Oli.Delivery.Sections.SectionResourceDepot.get_section_resource(
          section.id,
          page_revision.resource_id
        )

      assert section_resource.resource_type_id == ResourceType.id_for_page()
      assert section_resource.revision_id == page_revision.id

      {:ok, %StatementBundle{} = bundle} =
        XAPI.construct_bundle(
          %{
            "category" => "video",
            "event_type" => "played",
            "host_name" => "http://example.edu",
            "key" => %{"resource_id" => page_revision.resource_id, "section_id" => section.id},
            "video_url" => "https://example.edu/video.mp4",
            "video_title" => "Example video",
            "video_length" => 60,
            "video_play_time" => 0,
            "content_element_id" => "video-in-selected-branch"
          },
          user.id
        )

      assert [
               %{
                 "role" => "media_interaction",
                 "attribution_type" => "assignment",
                 "assignment_id" => assignment_id
               }
             ] =
               bundle
               |> statement_from_bundle()
               |> get_in(["context", "extensions", @experiment_attributions_key])

      assert assignment_id == assignment.id
    end

    test "does not return page revision content for resource-only events without assignments" do
      %{user: user, section: section, page_revision: page_revision, assignment: assignment} =
        setup_video_experiment_context()

      Repo.delete!(assignment)

      handler_id = "resource-video-revision-query-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          case {metadata.source, metadata.result} do
            {"revisions", {:ok, %Postgrex.Result{num_rows: num_rows}}} ->
              send(parent, {:revision_rows, num_rows})

            _ ->
              :ok
          end
        end,
        %{}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:ok, %StatementBundle{} = bundle} =
               XAPI.construct_bundle(
                 %{
                   "category" => "video",
                   "event_type" => "played",
                   "host_name" => "http://example.edu",
                   "key" => %{
                     "resource_id" => page_revision.resource_id,
                     "section_id" => section.id
                   },
                   "video_url" => "https://example.edu/video.mp4",
                   "video_title" => "Example video",
                   "video_length" => 60,
                   "video_play_time" => 0,
                   "content_element_id" => "video-in-selected-branch"
                 },
                 user.id
               )

      assert_receive {:revision_rows, 0}
      refute_receive {:revision_rows, _}

      refute bundle
             |> statement_from_bundle()
             |> get_in(["context", "extensions", @experiment_attributions_key])
    end
  end

  defp setup_video_experiment_context do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section = insert(:section, institution: institution, base_project: project)

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    alternatives_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_alternatives(),
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => [%{"id" => "alt-a", "name" => "Condition A"}]
        }
      )

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: page_content(alternatives_revision.resource_id)
      )

    insert(:project_resource,
      project_id: project.id,
      resource_id: alternatives_revision.resource_id
    )

    insert(:project_resource, project_id: project.id, resource_id: page_revision.resource_id)

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: page_revision.resource_id,
      revision: page_revision,
      resource_type_id: ResourceType.id_for_page()
    )

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: alternatives_revision.resource_id,
      revision: alternatives_revision,
      resource_type_id: ResourceType.id_for_alternatives()
    )

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    insert(:published_resource,
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: alternatives_revision.resource,
      revision: alternatives_revision
    )

    resource_access =
      insert(:resource_access,
        section: section,
        user: user,
        resource: page_revision.resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        content: page_revision.content
      )

    scope = %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }

    assignment = create_assignment(scope, alternatives_revision)

    Oli.Delivery.Sections.SectionResourceDepot.process_table_creation(section.id)

    %{
      user: user,
      section: section,
      page_revision: page_revision,
      resource_attempt: resource_attempt,
      experiment:
        Repo.get!(Oli.Experiments.Schemas.ExperimentDefinition, assignment.experiment_id),
      assignment: assignment,
      scope: scope
    }
  end

  defp create_assignment(%Scope{} = scope, alternatives_revision) do
    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "media-#{System.unique_integer([:positive])}",
        name: "Media experiment",
        algorithm: :weighted_random
      })

    {:ok, active} =
      Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: active.id,
        alternatives_resource_id: alternatives_revision.resource_id,
        decision_point_key: "alternatives:#{alternatives_revision.resource_id}"
      })
      |> Repo.insert!()

    %Condition{}
    |> Condition.changeset(%{
      experiment_id: active.id,
      decision_point_id: decision_point.id,
      condition_code: "condition-a",
      option_id: "alt-a",
      label: "Condition A",
      weight: 1.0,
      position: 0
    })
    |> Repo.insert!()

    {:ok, decision} =
      Experiments.assign_condition(%Oli.Experiments.AssignConditionRequest{
        scope: scope,
        alternatives_resource_id: alternatives_revision.resource_id,
        alternatives_revision_id: alternatives_revision.id,
        decision_point_key: "alternatives:#{alternatives_revision.resource_id}",
        available_condition_codes: ["condition-a"]
      })

    Repo.get!(Oli.Experiments.Schemas.Assignment, decision.assignment_id)
  end

  defp page_content(alternatives_resource_id) do
    %{
      "model" => [
        %{
          "type" => "alternatives",
          "alternatives_id" => alternatives_resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "value" => "alt-a",
              "children" => [
                %{"type" => "youtube", "id" => "video-in-selected-branch", "children" => []}
              ]
            },
            %{
              "type" => "alternative",
              "value" => "alt-b",
              "children" => [
                %{"type" => "youtube", "id" => "video-in-unselected-branch", "children" => []}
              ]
            }
          ]
        }
      ]
    }
  end

  defp statement_from_bundle(%StatementBundle{body: body}) do
    body
    |> String.trim()
    |> Jason.decode!()
  end
end
