defmodule Oli.Analytics.XAPI.UpgradeDataCaptureParityContractTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.XAPI.SchemaValidator
  alias Oli.Test.Support.UpgradeDataCaptureParityFixtures

  @attributions "http://oli.cmu.edu/extensions/experiment_attributions"
  @forbidden_payload_keys ~w(email given_name family_name lms_id raw_response response user_id)
  @allowed_attribution_keys MapSet.new(~w(
    activity_attempt_id activity_resource_id algorithm alternatives_resource_id
    alternatives_revision_id assigned_by_policy assignment_id assignment_key assignment_scope
    attribution_type condition_code condition_id enrollment_id experiment_id experiment_uuid
    institution_id intervention_id key outcome_key out_of policy_version project_id
    publication_id recorded_at resource_attempt_id reused reward_source reward_value role score
    section_id
  ))
  @attribution_roles ~w(media_interaction outcome reward rollup)
  @attribution_types ~w(assignment outcome reward)

  test "focused attempt and media fixtures validate against the xAPI schema" do
    fixture_path = write_fixture_statements()

    assert {:ok, %{total_lines: 8, valid_lines: 8, error_count: 0}} =
             SchemaValidator.validate_paths([fixture_path])
  end

  test "fixtures freeze existing producer roles, assignment scopes, and Thompson evidence" do
    fixtures = Map.new(UpgradeDataCaptureParityFixtures.statements(), &{&1.name, &1.statement})

    assert [
             %{"role" => "outcome", "attribution_type" => "outcome"},
             %{"role" => "reward", "attribution_type" => "reward"}
           ] =
             attributions(fixtures.attributed_part_attempt)

    assert [%{"role" => "rollup", "attribution_type" => "outcome"}] =
             attributions(fixtures.attributed_activity_attempt)

    assert [%{"role" => "rollup", "assignment_scope" => "intervention"}] =
             attributions(fixtures.attributed_page_attempt)

    assert [%{"role" => "rollup", "assignment_scope" => "section_enrollment"}] =
             attributions(fixtures.section_enrollment_attempt)

    assert [
             %{
               "role" => "rollup",
               "attribution_type" => "outcome",
               "algorithm" => "thompson_sampling",
               "policy_version" => "thompson_sampling:v2",
               "key" => "outcome:assignment-404:activity-attempt-801"
             },
             %{
               "role" => "rollup",
               "attribution_type" => "reward",
               "algorithm" => "thompson_sampling",
               "policy_version" => "thompson_sampling:v2",
               "key" => "reward:activity_attempt:801:assignment:404",
               "outcome_key" => "outcome:assignment-404:activity-attempt-801",
               "reward_source" => "activity_attempt:full_credit",
               "reward_value" => 1.0
             }
           ] =
             attributions(fixtures.thompson_attempt)

    assert [%{"role" => "media_interaction", "attribution_type" => "assignment"}] =
             attributions(fixtures.attributed_media)

    assert attributions(fixtures.unattributed_media) == []
    assert attributions(fixtures.unattributed_historical_attempt) == []
  end

  test "attribution fixtures contain only allowlisted, privacy-safe bounded fields" do
    UpgradeDataCaptureParityFixtures.statements()
    |> Enum.flat_map(&attributions(&1.statement))
    |> Enum.each(fn attribution ->
      assert attribution["role"] in @attribution_roles
      assert attribution["attribution_type"] in @attribution_types
      assert MapSet.subset?(MapSet.new(Map.keys(attribution)), @allowed_attribution_keys)
      assert byte_size(Jason.encode!(attribution)) <= 4_096
      assert Enum.all?(Map.values(attribution), &(not is_map(&1) and not is_list(&1)))
      assert Enum.all?(@forbidden_payload_keys, &(not contains_key?(attribution, &1)))
    end)
  end

  test "golden compatibility rows preserve v0.33.0 correctness fallback" do
    rows = UpgradeDataCaptureParityFixtures.compatibility_rows()

    assert Enum.map(rows, &compatibility_correctness(&1.score, &1.out_of)) ==
             Enum.map(rows, & &1.correctness)

    assert Enum.map(rows, &Map.take(&1, [:enrollment_id, :condition, :timestamp, :correctness])) ==
             [
               %{
                 enrollment_id: 501,
                 condition: "condition-a",
                 timestamp: ~U[2026-08-19 12:00:00Z],
                 correctness: 0.5
               },
               %{
                 enrollment_id: 502,
                 condition: "condition-b",
                 timestamp: ~U[2026-08-19 12:01:00Z],
                 correctness: 0.0
               },
               %{
                 enrollment_id: 503,
                 condition: "condition-a",
                 timestamp: ~U[2026-08-19 12:02:00Z],
                 correctness: 0.0
               },
               %{
                 enrollment_id: 504,
                 condition: "condition-b",
                 timestamp: ~U[2026-08-19 12:03:00Z],
                 correctness: 0.0
               }
             ]
  end

  defp write_fixture_statements do
    path = Path.join(System.tmp_dir!(), "upgrade_data_capture_parity_contract.jsonl")

    contents =
      UpgradeDataCaptureParityFixtures.statements()
      |> Enum.map_join("\n", &Jason.encode!(&1.statement))

    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp attributions(statement) do
    get_in(statement, ["context", "extensions", @attributions]) || []
  end

  defp contains_key?(value, forbidden_key) when is_map(value) do
    Map.has_key?(value, forbidden_key) or
      Enum.any?(Map.values(value), &contains_key?(&1, forbidden_key))
  end

  defp contains_key?(value, forbidden_key) when is_list(value),
    do: Enum.any?(value, &contains_key?(&1, forbidden_key))

  defp contains_key?(_value, _forbidden_key), do: false

  defp compatibility_correctness(score, _out_of) when score in [0.0, -0.0, nil], do: 0.0
  defp compatibility_correctness(_score, out_of) when out_of in [0.0, -0.0, nil], do: 0.0
  defp compatibility_correctness(score, out_of), do: score / out_of
end
