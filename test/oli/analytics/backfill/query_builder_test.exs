defmodule Oli.Analytics.Backfill.QueryBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.QueryBuilder

  @creds %{access_key_id: "AKIA_TEST", secret_access_key: "secret"}

  test "builds insert sql for JSONAsString format" do
    run = %BackfillRun{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONAsString"
    }

    sql = QueryBuilder.insert_sql(run, @creds)

    assert sql =~ "INSERT INTO analytics.raw_events"

    assert sql =~
             "FROM s3('s3://bucket/section/**/*.jsonl', 'AKIA_TEST', 'secret', 'JSONAsString', 'json String')"

    assert sql =~ "lower(hex(SHA256(json))) AS event_hash"

    assert sql =~ "publication_id, enrollment_id"

    assert sql =~
             "toUInt64OrNull(nullIf(JSON_VALUE(json, '$.context.extensions.\"http://oli.cmu.edu/extensions/enrollment_id\"'), '')) AS enrollment_id"

    assert sql =~
             "parseDateTime64BestEffortOrNull(nullIf(JSON_VALUE(json, '$.timestamp'), ''), 3) AS timestamp"

    refute sql =~ " AS event_id"
    refute sql =~ "JSONExtract(json, 'actor.account.name', 'Int64')"
    refute sql =~ "nullIf(JSON_VALUE(json, '$.statement.id'), '')"
    refute sql =~ "nullIf(JSON_VALUE(json, '$.statement.timestamp'), '')"
    refute sql =~ "nullIf(JSON_VALUE(json, '$.statement.actor.account.name'), '')"

    assert sql =~
             ~r/rowNumberInAllBlocks\(\)\s+- min\(rowNumberInAllBlocks\(\)\) OVER \(PARTITION BY _path\)\s+\+ 1 AS source_line/
  end

  test "builds dry run sql and uses NULL bytes expression for non JSONAsString format" do
    run = %BackfillRun{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONEachRow"
    }

    sql = QueryBuilder.dry_run_sql(run, @creds)

    assert sql =~ "SELECT"
    assert sql =~ "count() AS total_rows"
    assert sql =~ "NULL AS total_bytes"
    assert sql =~ "s3('s3://bucket/section/**/*.jsonl', 'AKIA_TEST', 'secret', 'JSONEACHROW')"
  end

  test "escapes single quotes in credentials and pattern" do
    run = %BackfillRun{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/it's/**/*.jsonl",
      format: "JSONAsString"
    }

    creds = %{access_key_id: "AKIA'TEST", secret_access_key: "sec'ret"}

    sql = QueryBuilder.insert_sql(run, creds)

    assert sql =~
             "s3('s3://bucket/it\\'s/**/*.jsonl', 'AKIA\\'TEST', 'sec\\'ret', 'JSONAsString', 'json String')"
  end

  test "preserves verb_id and canonical video mappings in insert sql" do
    run = %BackfillRun{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONAsString"
    }

    sql = QueryBuilder.insert_sql(run, @creds)

    assert sql =~ "timestamp, event_type, verb_id, page_id"
    assert sql =~ "nullIf(JSON_VALUE(json, '$.verb.id'), '') AS verb_id"

    assert sql =~
             "toFloat64OrNull(nullIf(JSON_VALUE(json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time\"'), '')) AS video_time"

    assert sql =~
             "toFloat64OrNull(nullIf(JSON_VALUE(json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time-from\"'), '')) AS video_seek_from"

    assert sql =~
             "toFloat64OrNull(nullIf(JSON_VALUE(json, '$.result.extensions.\"https://w3id.org/xapi/video/extensions/time-to\"'), '')) AS video_seek_to"

    refute sql =~ "video_play_time"
  end

  test "keeps experiment attribution concerns out of raw events insert sql" do
    run = %BackfillRun{
      target_table: "analytics.raw_events",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONAsString"
    }

    sql = QueryBuilder.insert_sql(run, @creds)

    refute sql =~ "has_experiment_attribution"
    refute sql =~ "experiment_attribution_count"
    refute sql =~ "experiment_attributions"
    refute sql =~ "experiment_event_type"
    refute sql =~ "'experiment'"
  end

  test "extracts attribution-level rows when target table is experiment_attributions" do
    run = %BackfillRun{
      target_table: "analytics.experiment_attributions",
      s3_pattern: "s3://bucket/section/**/*.jsonl",
      format: "JSONAsString"
    }

    sql = QueryBuilder.insert_sql(run, @creds)

    assert sql =~ "INSERT INTO analytics.experiment_attributions"
    assert sql =~ "raw_event_hash"
    assert sql =~ "raw_event_type"
    assert sql =~ "ARRAY JOIN JSONExtractArrayRaw"
    assert sql =~ "http://oli.cmu.edu/extensions/experiment_attributions"
    assert sql =~ "AS experiment_role"
    assert sql =~ "AS attribution_type"
    assert sql =~ "JSON_VALUE(attribution, '$.attribution_type')"
    assert sql =~ "throwIf"
    assert sql =~ "Invalid experiment attribution role/type pair"
    assert sql =~ "Experiment attribution key must be a non-empty string"

    assert sql =~
             "SHA256(concat(lower(hex(SHA256(json))), ':', JSON_VALUE(attribution, '$.key')))"

    assert sql =~ "AS experiment_uuid"
    assert sql =~ "AS assignment_scope"
    assert sql =~ "'intervention'"
    assert sql =~ "AS intervention_id"
    assert sql =~ "AS assessment_binding_id"
    assert sql =~ "AS resource_attempt_id"
    assert sql =~ "AS reward_threshold"
    assert sql =~ "AS normalized_score"
    assert sql =~ "AS page_revision_id"

    assert sql =~
             "toFloat64OrNull(nullIf(JSON_VALUE(attribution, '$.reward_value'), '')) AS reward_value"

    refute sql =~
             ~r/coalesce\(\s*toFloat64OrNull\(nullIf\(JSON_VALUE\(attribution, '\$\.reward_value'\).*result\.score\.raw/s

    refute sql =~ "key_hash"
    assert sql =~ "JSON_VALUE(attribution, '$.key')"
    refute sql =~ "outcome_id"
    refute sql =~ "reward_id"
    refute sql =~ "previous_policy_state_hash"
    refute sql =~ "next_policy_state_hash"
    refute sql =~ "algorithm_version"
    refute sql =~ "policy_update_reason"
    refute sql =~ "video_url"
    refute sql =~ "activity_attempt_guid"
    refute sql =~ "content_element_id"
  end

  test "replay maps every shared parity statement contract field" do
    fixture_path =
      Path.expand("../../../support/fixtures/upgrade_data_capture_parity_statement.json", __DIR__)

    statement = fixture_path |> File.read!() |> Jason.decode!()
    extensions = get_in(statement, ["context", "extensions"])
    attributions = extensions["http://oli.cmu.edu/extensions/experiment_attributions"]

    raw_sql =
      QueryBuilder.insert_sql(
        %BackfillRun{
          target_table: "analytics.raw_events",
          s3_pattern: "s3://bucket/parity.json",
          format: "JSONAsString"
        },
        @creds
      )

    attribution_sql =
      QueryBuilder.insert_sql(
        %BackfillRun{
          target_table: "analytics.experiment_attributions",
          s3_pattern: "s3://bucket/parity.json",
          format: "JSONAsString"
        },
        @creds
      )

    for field <-
          ~w(section_id project_id publication_id enrollment_id activity_attempt_guid activity_attempt_number page_attempt_guid page_attempt_number activity_id activity_revision_id) do
      assert Map.has_key?(extensions, "http://oli.cmu.edu/extensions/#{field}")
      assert raw_sql =~ "http://oli.cmu.edu/extensions/#{field}"
      assert raw_sql =~ "AS #{field}"
    end

    for field <-
          ~w(experiment_id experiment_uuid condition_id condition_code assignment_id assignment_key assignment_scope algorithm policy_version enrollment_id resource_attempt_id) do
      assert attribution_sql =~ "$.#{field}"
      assert attribution_sql =~ "AS #{field}"
    end

    assert Enum.any?(attributions, fn attribution ->
             attribution["attribution_type"] == "outcome" and
               not Map.has_key?(attribution, "reward_value")
           end)

    assert Enum.any?(attributions, fn attribution ->
             attribution["attribution_type"] == "reward" and
               attribution["reward_value"] == 0.0
           end)
  end
end
