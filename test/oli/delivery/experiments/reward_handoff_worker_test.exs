defmodule Oli.Delivery.Experiments.RewardHandoffWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.Delivery.Experiments.RewardHandoffWorker

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    DecisionPoint,
    ExperimentDefinition,
    ExperimentSection,
    Intervention
  }

  test "enqueues only one job per evaluated resource attempt" do
    %{section: section, resource_attempt: resource_attempt} = reward_context()

    assert :ok = RewardHandoffWorker.maybe_enqueue(resource_attempt.id, section.id)
    assert :ok = RewardHandoffWorker.maybe_enqueue(resource_attempt.id, section.id)

    assert [%Oban.Job{}] =
             all_enqueued(
               worker: RewardHandoffWorker,
               args: %{"resource_attempt_id" => resource_attempt.id}
             )
  end

  test "treats a missing resource attempt as a completed worker no-op" do
    assert :ok = perform_job(RewardHandoffWorker, %{"resource_attempt_id" => -1})
  end

  test "does not create a job for an unrelated page or inactive experiment" do
    %{experiment: experiment, section: section} = context = reward_context()
    unrelated_attempt = insert(:resource_attempt, resource_access: context.unrelated_access)

    assert :ok = RewardHandoffWorker.maybe_enqueue(unrelated_attempt.id, section.id)
    refute_enqueued(worker: RewardHandoffWorker)

    experiment
    |> ExperimentDefinition.changeset(%{state: :completed})
    |> Repo.update!()

    assert :ok = RewardHandoffWorker.maybe_enqueue(context.resource_attempt.id, section.id)
    refute_enqueued(worker: RewardHandoffWorker)
  end

  test "does not create a job for an experiment from another project" do
    %{experiment: experiment, section: section, resource_attempt: resource_attempt} =
      reward_context()

    experiment
    |> ExperimentDefinition.changeset(%{project_id: insert(:project).id})
    |> Repo.update!()

    assert :ok = RewardHandoffWorker.maybe_enqueue(resource_attempt.id, section.id)
    refute_enqueued(worker: RewardHandoffWorker)
  end

  defp reward_context do
    project = insert(:project)
    section = insert(:section, base_project: project)
    user = insert(:user)
    assessment_page = insert(:revision, graded: true)
    unrelated_page = insert(:revision, graded: true)

    resource_access =
      insert(:resource_access, section: section, user: user, resource: assessment_page.resource)

    unrelated_access =
      insert(:resource_access, section: section, user: user, resource: unrelated_page.resource)

    resource_attempt = insert(:resource_attempt, resource_access: resource_access)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "worker-enqueue-#{System.unique_integer([:positive])}",
        name: "Worker enqueue",
        state: :active,
        algorithm: :thompson_sampling
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{
      experiment_id: experiment.id,
      section_id: section.id
    })
    |> Repo.insert!()

    alternatives = insert(:revision)

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: experiment.id,
        alternatives_resource_id: alternatives.resource_id,
        decision_point_key: "worker-point",
        algorithm: :thompson_sampling,
        policy_config: %{}
      })
      |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        decision_point_id: decision_point.id,
        page_resource_id: alternatives.resource_id,
        content_element_id: "worker-placement"
      })
      |> Repo.insert!()

    %AssessmentBinding{}
    |> AssessmentBinding.changeset(%{
      intervention_id: intervention.id,
      assessment_page_resource_id: assessment_page.resource_id,
      reward_threshold: 1.0
    })
    |> Repo.insert!()

    %{
      experiment: experiment,
      resource_attempt: resource_attempt,
      section: section,
      unrelated_access: unrelated_access
    }
  end
end
