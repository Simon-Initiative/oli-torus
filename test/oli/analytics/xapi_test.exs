defmodule Oli.Analytics.XAPITest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Analytics.XAPI
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Experiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Experiments.Schemas.{Condition, DecisionPoint}
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
  end

  defp setup_video_experiment_context do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section =
      insert(:section, institution: institution, base_project: project, has_experiments: true)

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    alternatives_revision = insert(:revision)

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
      resource_id: page_revision.resource_id
    )

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
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

    %{
      user: user,
      resource_attempt: resource_attempt,
      experiment:
        Repo.get!(Oli.Experiments.Schemas.ExperimentDefinition, assignment.experiment_id),
      assignment: assignment
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
        alternatives_revision_id: alternatives_revision.id,
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
