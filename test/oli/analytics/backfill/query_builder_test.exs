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

    assert sql =~ "cityHash64(json) AS event_hash"

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
end
