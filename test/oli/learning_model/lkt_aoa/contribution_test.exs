defmodule Oli.LearningModel.LktAoa.ContributionTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.LktAoa.{BatchResult, Contribution}
  alias Oli.LearningModel.Parameters
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Resources.{ResourceType, Revision}

  test "objective extraction supports legacy list objectives and deduplicates direct IDs" do
    revision = %Revision{objectives: [10, 10, 11]}

    assert Contribution.objectives_for_part(revision, "part-1") == {:ok, [10, 11]}
  end

  test "objective extraction supports map objectives by part id" do
    revision = %Revision{objectives: %{"part-1" => [10, 10, 11], "part-2" => [12]}}

    assert Contribution.objectives_for_part(revision, "part-1") == {:ok, [10, 11]}
    assert Contribution.objectives_for_part(revision, "missing") == {:ok, []}
  end

  test "objective extraction rejects invalid objective shapes and IDs" do
    assert Contribution.objectives_for_part(%Revision{objectives: "bad"}, "part-1") ==
             {:error, {:invalid_objective_mapping, "bad"}}

    assert Contribution.objectives_for_part(
             %Revision{objectives: %{"part-1" => ["10"]}},
             "part-1"
           ) ==
             {:error, {:invalid_objective_id, "10"}}
  end

  test "same evidence key must keep the same effective objective mapping within a batch" do
    first = contribution(activity_id: 5, part_id: "part-1", learning_objective_ids: [1, 2])
    duplicate = contribution(activity_id: 5, part_id: "part-1", learning_objective_ids: [1, 2])
    conflicting = contribution(activity_id: 5, part_id: "part-1", learning_objective_ids: [1, 3])

    assert Contribution.validate_consistent_evidence_mappings([first, duplicate]) == :ok

    assert Contribution.validate_consistent_evidence_mappings([first, conflicting]) ==
             {:error, {:conflicting_objective_mapping, {1, 2, 5, "part-1"}, [1, 2], [1, 3]}}
  end

  test "activity beta uses exact typed activity parameters and preserves explicit zero" do
    revision =
      activity_revision(%{
        "part-1" => %PartParameters{beta_difficulty: 0.0},
        "part-2" => %PartParameters{beta_difficulty: -0.25}
      })

    assert Contribution.activity_part_beta(revision, "part-1") == {:ok, 0.0}
    assert Contribution.activity_part_beta(revision, "part-2") == {:ok, -0.25}
  end

  test "activity beta cold-starts only absent activity envelopes and part entries" do
    assert Contribution.activity_part_beta(
             %Revision{resource_type_id: ResourceType.id_for_activity()},
             "p"
           ) ==
             {:ok, 0.0}

    assert Contribution.activity_part_beta(activity_revision(%{}), "missing") == {:ok, 0.0}
  end

  test "activity beta rejects wrong resource type and wrong typed envelope" do
    learning_objective_envelope = %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %LearningObjectiveParameters{beta_lo: 0.1}
    }

    assert Contribution.activity_part_beta(
             %Revision{
               resource_type_id: ResourceType.id_for_objective(),
               learning_model_parameters: nil
             },
             "part"
           ) ==
             {:error,
              {:invalid_revision_resource_type, :activity, ResourceType.id_for_objective()}}

    assert Contribution.activity_part_beta(
             %Revision{
               resource_type_id: ResourceType.id_for_activity(),
               learning_model_parameters: learning_objective_envelope
             },
             "part"
           ) == {:error, {:invalid_activity_parameters, learning_objective_envelope}}
  end

  test "learning objective beta uses exact typed objective parameters and preserves explicit zero" do
    assert Contribution.learning_objective_beta(learning_objective_revision(0.0)) == {:ok, 0.0}
    assert Contribution.learning_objective_beta(learning_objective_revision(-0.5)) == {:ok, -0.5}
  end

  test "learning objective beta cold-starts absent envelope and rejects activity envelope" do
    activity_envelope = activity_parameters(%{})

    assert Contribution.learning_objective_beta(%Revision{
             resource_type_id: ResourceType.id_for_objective(),
             learning_model_parameters: nil
           }) == {:ok, 0.0}

    assert Contribution.learning_objective_beta(%Revision{
             resource_type_id: ResourceType.id_for_objective(),
             learning_model_parameters: activity_envelope
           }) == {:error, {:invalid_learning_objective_parameters, activity_envelope}}
  end

  test "binary outcome uses score equals out_of and ignores partial credit" do
    assert Contribution.binary_outcome(%{score: 1.0, out_of: 1.0}) == 1
    assert Contribution.binary_outcome(%{score: 0.5, out_of: 1.0}) == 0
    assert Contribution.binary_outcome(%{score: 0.0, out_of: 1.0}) == 0
  end

  test "state and evidence keys fan out one contribution to every direct objective" do
    contribution = contribution(learning_objective_ids: [10, 11])

    assert Contribution.evidence_key(contribution) == {1, 2, 3, "part-1"}
    assert Contribution.state_keys(contribution) == [{1, 2, 10}, {1, 2, 11}]
  end

  test "new evidence increments every targeted state once and ignores repeated evidence" do
    multi_lo = contribution(activity_id: 3, part_id: "part-1", learning_objective_ids: [10, 11])
    duplicate = contribution(activity_id: 3, part_id: "part-1", learning_objective_ids: [10, 11])
    other = contribution(activity_id: 4, part_id: "part-2", learning_objective_ids: [10])

    assert Contribution.confidence_increments_for_new_evidence(
             [multi_lo, duplicate, other],
             [{1, 2, 3, "part-1"}]
           ) == %{
             {1, 2, 10} => 1,
             {1, 2, 11} => 1
           }
  end

  test "batch result contains only aggregate fields" do
    result =
      BatchResult.new(:applied,
        input_attempt_count: 5,
        claimed_attempt_count: 4,
        contribution_count: 7,
        affected_state_count: 3,
        new_evidence_count: 2
      )

    assert Map.from_struct(result) == %{
             status: :applied,
             input_attempt_count: 5,
             claimed_attempt_count: 4,
             contribution_count: 7,
             affected_state_count: 3,
             new_evidence_count: 2
           }
  end

  defp contribution(attrs) do
    defaults = %{
      part_attempt_id: 1,
      part_attempt_guid: "guid-1",
      date_evaluated: ~U[2026-08-24 12:00:00Z],
      section_id: 1,
      user_id: 2,
      activity_id: 3,
      activity_revision_id: 4,
      part_id: "part-1",
      learning_objective_ids: [10],
      beta_part: 0.0,
      score: 1.0,
      out_of: 1.0
    }

    struct!(Contribution, Map.merge(defaults, Map.new(attrs)))
  end

  defp activity_revision(parts) do
    %Revision{
      resource_type_id: ResourceType.id_for_activity(),
      learning_model_parameters: activity_parameters(parts)
    }
  end

  defp activity_parameters(parts) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %ActivityParameters{parts: parts}
    }
  end

  defp learning_objective_revision(beta_lo) do
    %Revision{
      resource_type_id: ResourceType.id_for_objective(),
      learning_model_parameters: %Parameters{
        schema_version: 1,
        model: :lkt_aoa,
        model_version: 2,
        parameter_type: :learning_objective,
        payload: %LearningObjectiveParameters{beta_lo: beta_lo}
      }
    }
  end
end
