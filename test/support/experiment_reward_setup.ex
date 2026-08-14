defmodule Oli.Test.ExperimentRewardSetup do
  @moduledoc """
  Builds the persisted experiment graph needed to exercise assessment reward handoff paths.
  """

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.Enrollment

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    Assignment,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  alias Oli.Repo

  @doc """
  Creates an active Thompson experiment, binding, learner assignment, and initial policy state.
  """
  def create(project, section, resource_attempt) do
    resource_access = Repo.get!(ResourceAccess, resource_attempt.resource_access_id)

    enrollment =
      Repo.get_by(Enrollment, section_id: section.id, user_id: resource_access.user_id) ||
        %Enrollment{}
        |> Enrollment.changeset(%{
          section_id: section.id,
          user_id: resource_access.user_id
        })
        |> Repo.insert!()

    alternatives = Oli.Factory.insert(:revision)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "delayed-reward-#{System.unique_integer([:positive])}",
        name: "Delayed reward",
        state: :active,
        algorithm: :thompson_sampling,
        alternatives_resource_id: alternatives.resource_id
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: experiment.id, section_id: section.id})
    |> Repo.insert!()

    condition =
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: experiment.id,
        condition_code: "condition-a",
        option_id: "option-a",
        label: "Condition A",
        weight: 1.0,
        position: 0
      })
      |> Repo.insert!()

    %Condition{}
    |> Condition.changeset(%{
      experiment_id: experiment.id,
      condition_code: "condition-b",
      option_id: "option-b",
      label: "Condition B",
      weight: 1.0,
      position: 1
    })
    |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: experiment.id,
        page_resource_id: alternatives.resource_id,
        content_element_id: "delayed-reward-placement"
      })
      |> Repo.insert!()

    %AssessmentBinding{}
    |> AssessmentBinding.changeset(%{
      intervention_id: intervention.id,
      assessment_page_resource_id: resource_access.resource_id,
      reward_threshold: 1.0
    })
    |> Repo.insert!()

    policy_state =
      %PolicyState{}
      |> PolicyState.changeset(%{
        experiment_id: experiment.id,
        algorithm: :thompson_sampling,
        algorithm_version: "thompson_sampling:v2",
        state: %{
          "condition-a" => posterior(),
          "condition-b" => posterior()
        },
        prior_config: %{},
        reward_success_count: 0,
        reward_failure_count: 0,
        assignment_count: 1
      })
      |> Repo.insert!()

    %Assignment{}
    |> Assignment.changeset(%{
      experiment_id: experiment.id,
      condition_id: condition.id,
      intervention_id: intervention.id,
      section_id: section.id,
      enrollment_id: enrollment.id,
      user_id: resource_access.user_id,
      assigned_by_policy: "thompson_sampling",
      policy_version: "thompson_sampling:v2",
      assignment_key: "delayed-reward-assignment-#{System.unique_integer([:positive])}",
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second),
      runtime_event_state: %{}
    })
    |> Repo.insert!()

    %{experiment: experiment, policy_state: policy_state}
  end

  defp posterior do
    %{
      "prior_alpha" => 1.0,
      "prior_beta" => 1.0,
      "successes" => 0,
      "failures" => 0,
      "posterior_alpha" => 1.0,
      "posterior_beta" => 1.0
    }
  end
end
