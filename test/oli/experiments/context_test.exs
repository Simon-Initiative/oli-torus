defmodule Oli.Experiments.ContextTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    CreateExperimentRequest,
    ExperimentDefinition,
    ExperimentError,
    LifecycleRequest,
    Scope,
    UpdateExperimentRequest
  }

  describe "create_experiment/1" do
    test "creates an experiment through the public context boundary" do
      scope = valid_scope()

      assert {:ok, %ExperimentDefinition{} = definition} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: scope,
                 slug: "native-ab",
                 name: "Native A/B",
                 description: "A native experiment",
                 algorithm: :weighted_random,
                 policy_config: %{"salt" => "stable"}
               })

      assert definition.id
      assert definition.uuid
      assert definition.institution_id == scope.institution_id
      assert definition.project_id == scope.project_id
      assert definition.publication_id == scope.publication_id
      assert definition.section_id == scope.section_id
      assert definition.state == :draft
      refute private_schema?(definition)
    end

    test "rejects invalid cross-project publication scope" do
      scope = valid_scope()
      other_publication = insert(:publication)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | publication_id: other_publication.id},
                 slug: "native-ab",
                 name: "Native A/B",
                 algorithm: :weighted_random
               })

      assert message == "publication does not belong to project"
    end

    test "rejects invalid cross-section and cross-enrollment scope" do
      scope = valid_scope()
      other_section = insert(:section)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | section_id: other_section.id},
                 slug: "native-ab",
                 name: "Native A/B",
                 algorithm: :weighted_random
               })

      assert message in [
               "section does not belong to institution",
               "section does not belong to project"
             ]

      other_enrollment = insert(:enrollment)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: %{scope | enrollment_id: other_enrollment.id},
                 slug: "native-ab",
                 name: "Native A/B",
                 algorithm: :weighted_random
               })

      assert message in [
               "enrollment does not belong to section",
               "enrollment does not belong to user"
             ]
    end

    test "normalizes persistence validation errors to public error structs" do
      scope = valid_scope()

      assert {:error, %ExperimentError{type: :persistence_error, details: %{errors: errors}}} =
               Experiments.create_experiment(%CreateExperimentRequest{
                 scope: scope,
                 slug: "",
                 name: "",
                 algorithm: :weighted_random
               })

      assert %{
               slug: ["can't be blank"],
               name: ["can't be blank"]
             } =
               errors
    end
  end

  describe "update_experiment/2" do
    test "updates draft experiment fields and returns a public domain struct" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:ok, %ExperimentDefinition{} = updated} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{
                   scope: scope,
                   name: "Updated name",
                   description: "Updated description",
                   policy_config: %{"salt" => "new"}
                 }
               )

      assert updated.name == "Updated name"
      assert updated.description == "Updated description"
      assert updated.policy_config == %{"salt" => "new"}
      refute private_schema?(updated)
    end

    test "rejects updates outside the experiment scope" do
      scope = valid_scope()
      definition = create_definition!(scope)
      other_project = insert(:project)

      assert {:error, %ExperimentError{type: :invalid_scope, message: message}} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{
                   scope: %{scope | project_id: other_project.id},
                   name: "Bad"
                 }
               )

      assert message in [
               "publication does not belong to project",
               "section does not belong to project"
             ]
    end

    test "rejects updates once the experiment is active" do
      scope = valid_scope()
      definition = create_definition!(scope)
      assert {:ok, _active} = Experiments.activate_experiment(definition.id, lifecycle(scope))

      assert {:error, %ExperimentError{type: :invalid_state}} =
               Experiments.update_experiment(
                 definition.id,
                 %UpdateExperimentRequest{scope: scope, name: "Too late"}
               )
    end
  end

  describe "lifecycle commands" do
    test "supports allowed lifecycle transitions with timestamps" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:ok, %ExperimentDefinition{state: :active, started_at: started_at} = active} =
               Experiments.activate_experiment(definition.id, lifecycle(scope))

      assert started_at

      assert {:ok, %ExperimentDefinition{state: :paused}} =
               Experiments.pause_experiment(active.id, lifecycle(scope))

      assert {:ok, %ExperimentDefinition{state: :active}} =
               Experiments.activate_experiment(active.id, lifecycle(scope))

      assert {:ok, %ExperimentDefinition{state: :completed, ended_at: ended_at} = completed} =
               Experiments.complete_experiment(active.id, lifecycle(scope))

      assert ended_at

      assert {:ok, %ExperimentDefinition{state: :archived}} =
               Experiments.archive_experiment(completed.id, lifecycle(scope))
    end

    test "rejects invalid lifecycle transitions" do
      scope = valid_scope()
      definition = create_definition!(scope)

      assert {:error, %ExperimentError{type: :invalid_state, message: message}} =
               Experiments.pause_experiment(definition.id, lifecycle(scope))

      assert message == "experiment cannot transition from draft to paused"
    end
  end

  describe "public response shapes" do
    test "public API functions do not return private Ecto schemas" do
      scope = valid_scope()
      definition = create_definition!(scope)

      {:ok, updated} =
        Experiments.update_experiment(
          definition.id,
          %UpdateExperimentRequest{scope: scope, name: "Public response"}
        )

      {:ok, active} = Experiments.activate_experiment(definition.id, lifecycle(scope))

      refute private_schema?(definition)
      refute private_schema?(updated)
      refute private_schema?(active)
    end
  end

  defp valid_scope do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }
  end

  defp create_definition!(scope) do
    assert {:ok, definition} =
             Experiments.create_experiment(%CreateExperimentRequest{
               scope: scope,
               slug: "native-ab-#{System.unique_integer([:positive])}",
               name: "Native A/B",
               algorithm: :weighted_random
             })

    definition
  end

  defp lifecycle(scope), do: %LifecycleRequest{scope: scope}

  defp private_schema?(struct) do
    struct.__struct__
    |> Module.split()
    |> Enum.take(3)
    |> Kernel.==(["Oli", "Experiments", "Schemas"])
  end
end
