defmodule Oli.LearningModel.Parameters.ValidationTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.{Parameters, PartIds}
  alias Oli.LearningModel.Parameters.Validation
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Resources.ResourceType

  test "validates parameter type against the Revision resource type" do
    lo_parameters = learning_objective_parameters(-0.42)
    activity_parameters = activity_parameters(%{"part-1" => -0.18})
    content = standard_content(["part-1"])

    assert :ok =
             Validation.validate_for_revision(
               lo_parameters,
               ResourceType.id_for_objective(),
               %{}
             )

    assert :ok =
             Validation.validate_for_revision(
               activity_parameters,
               ResourceType.id_for_activity(),
               content
             )

    assert {:error, [learning_model_parameters: message]} =
             Validation.validate_for_revision(
               lo_parameters,
               ResourceType.id_for_activity(),
               %{}
             )

    assert message =~ "does not match"
    assert :ok = Validation.validate_for_revision(nil, ResourceType.id_for_page(), %{})
  end

  test "rejects explicitly configured activity parts missing from the same content" do
    parameters = activity_parameters(%{"part-1" => 0.1, "deleted-part" => 0.2})

    assert {:error, [learning_model_parameters: message]} =
             Validation.validate_for_revision(
               parameters,
               ResourceType.id_for_activity(),
               standard_content(["part-1"])
             )

    assert message == "unknown activity part IDs: deleted-part"
  end

  test "bounds unknown-part diagnostics for externally supplied parameter maps" do
    parts = Map.new(1..10, fn index -> {"unknown-#{index}", 0.1} end)

    assert {:error, [learning_model_parameters: message]} =
             Validation.validate_for_revision(
               activity_parameters(parts),
               ResourceType.id_for_activity(),
               standard_content([])
             )

    assert message =~ "unknown activity part IDs:"
    assert message =~ "(+5 more)"
    assert length(String.split(message, ",")) == 5
  end

  test "extracts standard map and legacy string part IDs" do
    content = %{
      "authoring" => %{
        "parts" => [%{"id" => "part-1"}, "legacy-part", %{"id" => nil}]
      }
    }

    assert PartIds.for_content(content) == MapSet.new(["part-1", "legacy-part"])
  end

  test "reuses persisted adaptive-part semantics" do
    content = %{
      "partsLayout" => [
        %{"id" => "scored", "type" => "janus-mcq"},
        %{"id" => "stateful", "type" => "janus-navigation-button"},
        %{"id" => "display-only", "type" => "janus-formula"}
      ],
      "authoring" => %{
        "parts" => [
          %{"id" => "scored", "type" => "janus-mcq"},
          %{"id" => "stateful", "type" => "janus-navigation-button"},
          %{"id" => "display-only", "type" => "janus-formula"}
        ],
        "rules" => []
      }
    }

    assert PartIds.for_content(content) == MapSet.new(["scored", "stateful"])

    assert :ok =
             Validation.validate_for_revision(
               activity_parameters(%{"scored" => 0.1, "stateful" => 0.2}),
               ResourceType.id_for_activity(),
               content
             )

    assert {:error, [learning_model_parameters: message]} =
             Validation.validate_for_revision(
               activity_parameters(%{"display-only" => 0.1}),
               ResourceType.id_for_activity(),
               content
             )

    assert message =~ "display-only"
  end

  test "reconciliation prunes deleted parts and does not synthesize new ones" do
    original = activity_parameters(%{"kept" => 0.1, "deleted" => 0.2})

    assert %Parameters{
             payload: %ActivityParameters{
               parts: %{"kept" => %PartParameters{beta_difficulty: 0.1}}
             }
           } =
             Validation.reconcile_inherited_parts(
               original,
               standard_content(["kept", "new-untrained"])
             )
  end

  test "reconciliation leaves learning-objective and missing parameters unchanged" do
    lo_parameters = learning_objective_parameters(0.0)

    assert Validation.reconcile_inherited_parts(lo_parameters, %{}) == lo_parameters
    assert Validation.reconcile_inherited_parts(nil, %{}) == nil
  end

  defp learning_objective_parameters(beta_lo) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :learning_objective,
      payload: %LearningObjectiveParameters{beta_lo: beta_lo}
    }
  end

  defp activity_parameters(parts) do
    %Parameters{
      schema_version: 1,
      model: :lkt_aoa,
      model_version: 2,
      parameter_type: :activity,
      payload: %ActivityParameters{
        parts:
          Map.new(parts, fn {part_id, beta_difficulty} ->
            {part_id, %PartParameters{beta_difficulty: beta_difficulty}}
          end)
      }
    }
  end

  defp standard_content(part_ids) do
    %{"authoring" => %{"parts" => Enum.map(part_ids, &%{"id" => &1})}}
  end
end
