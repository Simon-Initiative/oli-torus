defmodule Oli.Delivery.Experiments.RewardHandoffWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory

  alias Oli.Delivery.Experiments.RewardHandoffWorker
  alias Oli.Experiments.Schemas.{ExperimentDefinition, ExperimentSection}

  test "enqueues only one job per evaluated activity attempt" do
    section = participating_section()

    assert :ok = RewardHandoffWorker.enqueue(123, section.id)
    assert :ok = RewardHandoffWorker.enqueue(123, section.id)

    assert [%Oban.Job{}] =
             all_enqueued(worker: RewardHandoffWorker, args: %{"activity_attempt_ids" => [123]})
  end

  test "normalizes a batch and treats missing activity attempts as a completed no-op" do
    section = participating_section()

    assert :ok = RewardHandoffWorker.enqueue([3, 1, 3, "invalid"], section.id)

    assert_enqueued(
      worker: RewardHandoffWorker,
      args: %{"activity_attempt_ids" => [1, 3]}
    )

    assert :ok = perform_job(RewardHandoffWorker, %{"activity_attempt_ids" => [-1]})
    assert :ok = perform_job(RewardHandoffWorker, %{"activity_attempt_ids" => [-2, -1]})
  end

  test "does not create a job when the section has no experiment" do
    section = insert(:section)

    assert :ok = RewardHandoffWorker.enqueue(123, section.id)

    refute_enqueued(worker: RewardHandoffWorker)
  end

  test "enqueue/1 resolves the section and applies the experiment guard" do
    participating_attempt = participating_section() |> activity_attempt()
    ordinary_attempt = insert(:section) |> activity_attempt()

    assert :ok =
             RewardHandoffWorker.enqueue([participating_attempt.id, ordinary_attempt.id])

    assert_enqueued(
      worker: RewardHandoffWorker,
      args: %{"activity_attempt_ids" => [participating_attempt.id]}
    )

    refute_enqueued(
      worker: RewardHandoffWorker,
      args: %{"activity_attempt_ids" => [ordinary_attempt.id]}
    )
  end

  defp participating_section do
    project = insert(:project)
    section = insert(:section, base_project: project)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "worker-enqueue-#{System.unique_integer([:positive])}",
        name: "Worker enqueue",
        algorithm: :weighted_random
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{
      experiment_id: experiment.id,
      section_id: section.id
    })
    |> Repo.insert!()

    section
  end

  defp activity_attempt(section) do
    user = insert(:user)
    page_revision = insert(:revision)

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
        content: %{"model" => []}
      )

    activity_revision = insert(:revision)

    insert(:activity_attempt,
      resource_attempt: resource_attempt,
      revision: activity_revision,
      resource: activity_revision.resource
    )
  end
end
