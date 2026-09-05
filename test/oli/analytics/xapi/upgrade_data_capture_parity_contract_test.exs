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
  @compatibility_query Path.expand(
                         "../../../../priv/clickhouse/queries/upgrade_v033_compatibility.sql",
                         __DIR__
                       )

  # Implementation proof: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007,
  # AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014.

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

    assert get_in(fixtures.attributed_activity_attempt, ["verb", "id"]) ==
             "http://adlnet.gov/expapi/verbs/completed"

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

  test "compatibility fixture join covers section-wide v0.33.0 analysis parity" do
    rows = compatibility_join()

    assert Enum.map(rows, &Map.take(&1, [:enrollment_id, :condition, :timestamp, :correctness])) ==
             [
               %{
                 enrollment_id: 501,
                 condition: "condition-a",
                 timestamp: ~U[2026-08-19 12:00:00Z],
                 correctness: 0.5
               },
               %{
                 enrollment_id: 501,
                 condition: "condition-a",
                 timestamp: ~U[2026-08-19 12:05:00Z],
                 correctness: 1.0
               },
               %{
                 enrollment_id: 501,
                 condition: "condition-a",
                 timestamp: ~U[2026-08-19 12:06:00Z],
                 correctness: 0.25
               },
               %{
                 enrollment_id: 502,
                 condition: "condition-b",
                 timestamp: ~U[2026-08-19 12:07:00Z],
                 correctness: 0.75
               },
               %{
                 enrollment_id: 503,
                 condition: "condition-c",
                 timestamp: ~U[2026-08-19 12:08:00Z],
                 correctness: 0.0
               },
               %{
                 enrollment_id: 503,
                 condition: "condition-c",
                 timestamp: ~U[2026-08-19 12:09:00Z],
                 correctness: 0.0
               }
             ]

    assert rows |> Enum.map(& &1.enrollment_id) |> Enum.uniq() |> length() == 3
    assert rows |> Enum.map(& &1.activity_id) |> Enum.uniq() |> length() == 5
    assert Enum.count(rows, &(&1.activity_attempt_guid == "attempt-501-a")) == 2
    assert Enum.any?(rows, &(&1.branch_relationship == :in_branch))
    assert Enum.any?(rows, &(&1.branch_relationship == :out_of_branch))

    assert MapSet.new(Enum.map(rows, & &1.assignment_scope)) ==
             MapSet.new(~w(intervention section_enrollment))

    assert MapSet.new(Enum.map(rows, & &1.algorithm)) ==
             MapSet.new(~w(thompson_sampling weighted_random))

    refute Enum.any?(rows, &String.starts_with?(&1.event_hash, "excluded-"))
  end

  test "repository-owned compatibility query joins assignment evidence and normalizes only correctness" do
    sql = File.read!(@compatibility_query)

    assert sql =~ "{section_id:UInt64}"
    assert sql =~ "{experiment_id:UInt64}"
    assert sql =~ "{evidence_from_timestamp:DateTime64(3)}"
    assert sql =~ "{from_timestamp:DateTime64(3)}"
    assert sql =~ "{to_timestamp:DateTime64(3)}"
    assert sql =~ "ASOF LEFT JOIN"
    assert sql =~ "raw.raw_project_id = evidence.evidence_project_id"
    assert sql =~ "raw.participant_id = evidence.participant_id"
    assert sql =~ "raw.timestamp >= evidence.timestamp"
    assert sql =~ "attribution_type = 'assignment'"
    assert sql =~ "experiment_id = {experiment_id:UInt64}"
    assert sql =~ "verb_id = 'http://adlnet.gov/expapi/verbs/completed'"
    refute sql =~ "verb_id = 'http://adlnet.gov/expapi/verbs/evaluated'"

    assert sql =~
             "argMax(condition_code, tuple(event_version, attribution_hash)) AS selected_condition_code"

    assert sql =~ "ifNotFinite(raw.score / raw.out_of, toFloat64(0))"
    refute sql =~ ~r/AS\s+(score|out_of)\b/
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

  defp compatibility_join do
    evidence =
      UpgradeDataCaptureParityFixtures.compatibility_assignment_evidence()
      |> Enum.filter(
        &(&1.section_id == 2001 and &1.experiment_id == 101 and
            &1.attribution_type == "assignment" and
            not is_nil(&1.enrollment_id) and not is_nil(&1.project_id) and
            not is_nil(&1.condition) and
            DateTime.compare(&1.timestamp, ~U[2026-08-01 00:00:00Z]) != :lt and
            DateTime.compare(&1.timestamp, ~U[2026-08-20 00:00:00Z]) != :gt)
      )
      |> Enum.group_by(&{&1.section_id, &1.project_id, &1.enrollment_id, &1.timestamp})
      |> Enum.map(fn {_key, same_timestamp_rows} ->
        Enum.max_by(same_timestamp_rows, fn row ->
          {DateTime.to_unix(row.event_version, :microsecond), row.attribution_hash}
        end)
      end)

    (UpgradeDataCaptureParityFixtures.compatibility_activity_events() ++
       UpgradeDataCaptureParityFixtures.compatibility_excluded_activity_events())
    |> Enum.filter(
      &(&1.event_type == "activity_attempt" and
          &1.verb_id == "http://adlnet.gov/expapi/verbs/completed" and
          DateTime.compare(&1.timestamp, ~U[2026-08-19 12:00:00Z]) != :lt and
          DateTime.compare(&1.timestamp, ~U[2026-08-20 00:00:00Z]) == :lt)
    )
    |> Enum.map(fn event ->
      assignment =
        evidence
        |> Enum.filter(
          &(&1.section_id == event.section_id and &1.project_id == event.project_id and
              &1.enrollment_id == event.enrollment_id and
              DateTime.compare(&1.timestamp, event.timestamp) != :gt)
        )
        |> Enum.max_by(& &1.timestamp, DateTime, fn -> nil end)

      case assignment do
        nil ->
          nil

        assignment ->
          event
          |> Map.merge(Map.take(assignment, [:condition, :algorithm, :assignment_scope]))
          |> Map.put(:correctness, compatibility_correctness(event.score, event.out_of))
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&{&1.enrollment_id, &1.timestamp, &1.event_hash})
  end
end
