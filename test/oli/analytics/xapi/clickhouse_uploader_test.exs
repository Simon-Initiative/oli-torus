defmodule Oli.Analytics.XAPI.ClickHouseUploaderTest do
  use ExUnit.Case, async: true

  import Mox

  alias Oli.Analytics.XAPI.ClickHouseUploader
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Test.MockHTTP

  @fixture_path Path.expand(
                  "../../../../cloud/xapi-etl-processor/tests/fixtures/experiment_attributed_part_attempt.jsonl",
                  __DIR__
                )
  @fixture_event_hash "1324eea1ad081cb5cbd2f7e8859bd5ba339b5b2bb9a28ced3c70d5f08bee062a"
  @fixture_attribution_hash "4ab96ee53f4775c80d5bc1471f4e6c1d2ee514d5a12e0b6c1df56c5a81bcb257"

  setup :verify_on_exit!

  setup do
    original_clickhouse = Application.get_env(:oli, :clickhouse)
    original_http_client = Application.get_env(:oli, :http_client)

    Application.put_env(:oli, :http_client, MockHTTP)

    Application.put_env(:oli, :clickhouse,
      host: "http://clickhouse.test",
      database: "analytics",
      http_port: 8123,
      admin_user: "user",
      admin_password: "pass"
    )

    on_exit(fn ->
      if is_nil(original_clickhouse) do
        Application.delete_env(:oli, :clickhouse)
      else
        Application.put_env(:oli, :clickhouse, original_clickhouse)
      end

      if is_nil(original_http_client) do
        Application.delete_env(:oli, :http_client)
      else
        Application.put_env(:oli, :http_client, original_http_client)
      end
    end)

    :ok
  end

  test "upload emits verb_id and canonical video columns for supported video statements" do
    played =
      video_statement("https://w3id.org/xapi/video/verbs/played", %{
        "https://w3id.org/xapi/video/extensions/time" => 12.5
      })

    paused =
      video_statement("https://w3id.org/xapi/video/verbs/paused", %{
        "https://w3id.org/xapi/video/extensions/time" => 18.25,
        "https://w3id.org/xapi/video/extensions/progress" => 33.0,
        "https://w3id.org/xapi/video/extensions/played-segments" => "0[.]18.25"
      })

    seeked =
      video_statement("https://w3id.org/xapi/video/verbs/seeked", %{
        "https://w3id.org/xapi/video/extensions/time-from" => 18.25,
        "https://w3id.org/xapi/video/extensions/time-to" => 42.0
      })

    completed =
      video_statement("https://w3id.org/xapi/video/verbs/completed", %{
        "https://w3id.org/xapi/video/extensions/time" => 90.0,
        "https://w3id.org/xapi/video/extensions/progress" => 100.0,
        "https://w3id.org/xapi/video/extensions/played-segments" => "0[.]90"
      })

    body =
      Enum.map_join([played, paused, seeked, completed], "\n", &Jason.encode!/1)

    bundle = %StatementBundle{body: body, category: :video, bundle_id: "bundle-1"}

    expect(MockHTTP, :post, fn url, query, headers ->
      assert url == "http://clickhouse.test:8123/?database=analytics"
      assert {"X-ClickHouse-User", "user"} in headers
      assert {"X-ClickHouse-Key", "pass"} in headers
      assert query =~ "verb_id"
      assert query =~ "'https://w3id.org/xapi/video/verbs/played'"
      assert query =~ "'https://w3id.org/xapi/video/verbs/paused'"
      assert query =~ "'https://w3id.org/xapi/video/verbs/seeked'"
      assert query =~ "'https://w3id.org/xapi/video/verbs/completed'"
      assert query =~ "'https://cdn.example.edu/video.mp4'"
      assert query =~ "12.5"
      assert query =~ "33.0"
      assert query =~ "18.25"
      assert query =~ "42.0"
      assert query =~ "100.0"
      refute query =~ "video_play_time"
      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 4} = ClickHouseUploader.upload(bundle)
  end

  test "upload accepts legacy attempt verbs and both OLI extension key schemes" do
    answered_activity =
      %{
        "actor" => %{
          "mbox" => "mailto:student@example.edu",
          "account" => %{
            "homePage" => "https://proton.oli.cmu.edu",
            "name" => "student@example.edu"
          }
        },
        "verb" => %{"id" => "http://adlnet.gov/expapi/verbs/answered"},
        "context" => %{
          "extensions" => %{
            "https://oli.cmu.edu/extensions/section_id" => 111,
            "https://oli.cmu.edu/extensions/project_id" => 222,
            "https://oli.cmu.edu/extensions/publication_id" => 333,
            "https://oli.cmu.edu/extensions/activity_attempt_guid" => "activity-guid",
            "https://oli.cmu.edu/extensions/activity_attempt_number" => 4,
            "https://oli.cmu.edu/extensions/page_attempt_guid" => "page-guid",
            "https://oli.cmu.edu/extensions/page_attempt_number" => 3,
            "https://oli.cmu.edu/extensions/activity_id" => 444,
            "https://oli.cmu.edu/extensions/activity_revision_id" => 555
          }
        },
        "result" => %{
          "score" => %{"raw" => 8, "max" => 10, "scaled" => 0.8},
          "success" => true,
          "completion" => true,
          "response" => "choice_a",
          "extensions" => %{"https://oli.cmu.edu/extensions/feedback" => "nice work"}
        },
        "timestamp" => "2026-03-27T12:00:00Z"
      }

    experienced_page =
      %{
        "actor" => %{
          "mbox" => "mailto:student@example.edu",
          "account" => %{
            "homePage" => "https://proton.oli.cmu.edu",
            "name" => "student@example.edu"
          }
        },
        "verb" => %{"id" => "http://adlnet.gov/expapi/verbs/experienced"},
        "object" => %{
          "id" => "https://proton.oli.cmu.edu/page/1",
          "definition" => %{"type" => "http://oli.cmu.edu/extensions/types/page"}
        },
        "context" => %{
          "extensions" => %{
            "https://oli.cmu.edu/extensions/section_id" => 111,
            "https://oli.cmu.edu/extensions/project_id" => 222,
            "https://oli.cmu.edu/extensions/publication_id" => 333,
            "https://oli.cmu.edu/extensions/page_id" => 444
          }
        },
        "result" => %{"completion" => false},
        "timestamp" => "2026-03-27T12:01:00Z"
      }

    body = Enum.map_join([answered_activity, experienced_page], "\n", &Jason.encode!/1)
    bundle = %StatementBundle{body: body, category: :video, bundle_id: "bundle-2"}

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "'http://adlnet.gov/expapi/verbs/answered'"
      assert query =~ "'activity-guid'"
      assert query =~ "'nice work'"
      assert query =~ "'http://adlnet.gov/expapi/verbs/experienced'"
      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 2} = ClickHouseUploader.upload(bundle)
  end

  test "upload maps host statement experiment attribution arrays into attribution table rows" do
    statement = attributed_part_attempt_statement()

    bundle = %StatementBundle{
      body: Jason.encode!(statement),
      category: :attempt,
      bundle_id: "bundle-exp"
    }

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "'part_attempt'"
      refute query =~ "has_experiment_attribution"
      refute query =~ "experiment_attribution_count"
      refute query =~ "experiment_uuid"
      refute query =~ "experiment_event_type"
      {:ok, %{status_code: 200, body: ""}}
    end)

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "INSERT INTO analytics.experiment_attributions"
      assert query =~ "raw_event_hash"
      assert query =~ "experiment_role"
      assert query =~ "attribution_type"
      assert query =~ "'reward'"
      assert query =~ "101"
      assert query =~ "'11111111-2222-3333-4444-555555555555'"
      assert query =~ "'condition-a'"
      assert query =~ "policy_version"
      refute query =~ sha256("reward-key")
      refute query =~ "'reward-key'"
      assert query =~ "'activity_attempt:full_credit'"
      refute query =~ "key_hash"
      refute query =~ "algorithm_version"
      refute query =~ "policy_update_reason"
      refute query =~ "outcome_id"
      refute query =~ "reward_id"
      refute query =~ "previous_policy_state_hash"
      refute query =~ "next_policy_state_hash"
      refute query =~ "video_url"
      refute query =~ "activity_attempt_guid"
      refute query =~ "content_element_id"
      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 1} = ClickHouseUploader.upload(bundle)
  end

  test "upload preserves outcome type independently from rollup role" do
    statement =
      attributed_part_attempt_statement()
      |> put_in(
        [
          "context",
          "extensions",
          "http://oli.cmu.edu/extensions/experiment_attributions",
          Access.at(0),
          "role"
        ],
        "rollup"
      )
      |> put_in(
        [
          "context",
          "extensions",
          "http://oli.cmu.edu/extensions/experiment_attributions",
          Access.at(0),
          "attribution_type"
        ],
        "outcome"
      )

    bundle = %StatementBundle{
      body: Jason.encode!(statement),
      category: :attempt,
      bundle_id: "bundle-rollup"
    }

    expect(MockHTTP, :post, fn _url, _query, _headers ->
      {:ok, %{status_code: 200, body: ""}}
    end)

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "experiment_role"
      assert query =~ "attribution_type"
      assert query =~ "'rollup'"
      assert query =~ "'outcome'"
      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 1} = ClickHouseUploader.upload(bundle)
  end

  @tag capture_log: true
  test "upload fails for a missing required attribution type" do
    statement =
      update_in(
        attributed_part_attempt_statement(),
        [
          "context",
          "extensions",
          "http://oli.cmu.edu/extensions/experiment_attributions",
          Access.at(0)
        ],
        &Map.delete(&1, "attribution_type")
      )

    bundle = %StatementBundle{
      body: Jason.encode!(statement),
      category: :attempt,
      bundle_id: "bundle-missing-type"
    }

    assert {:error, {:invalid_experiment_attribution, %{role: "reward", type: nil}}} =
             ClickHouseUploader.upload(bundle)
  end

  @tag capture_log: true
  test "upload fails for a missing attribution idempotency key" do
    statement =
      update_in(
        attributed_part_attempt_statement(),
        [
          "context",
          "extensions",
          "http://oli.cmu.edu/extensions/experiment_attributions",
          Access.at(0)
        ],
        &Map.delete(&1, "key")
      )

    bundle = %StatementBundle{
      body: Jason.encode!(statement),
      category: :attempt,
      bundle_id: "bundle-missing-key"
    }

    assert {:error, {:invalid_experiment_attribution_key, nil}} =
             ClickHouseUploader.upload(bundle)
  end

  test "raw event and attribution hashes match lambda raw-line hashing contract" do
    raw_line = attributed_part_attempt_json_line()
    reencoded_hash = raw_line |> Jason.decode!() |> Jason.encode!() |> sha256()

    assert sha256(raw_line) == @fixture_event_hash
    refute @fixture_event_hash == reencoded_hash

    bundle = %StatementBundle{
      body: raw_line,
      category: :attempt,
      bundle_id: "bundle-hash"
    }

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "'#{@fixture_event_hash}'"
      refute query =~ "'#{reencoded_hash}'"
      {:ok, %{status_code: 200, body: ""}}
    end)

    expect(MockHTTP, :post, fn _url, query, _headers ->
      assert query =~ "'#{@fixture_event_hash}'"
      assert query =~ "'#{@fixture_attribution_hash}'"
      refute query =~ "'#{reencoded_hash}'"
      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 1} = ClickHouseUploader.upload(bundle)
  end

  test "inserts experiment attributions in bounded chunks" do
    bundle = attributed_bundle(501, "bundle-chunks")
    {:ok, attribution_queries} = Agent.start_link(fn -> [] end)

    expect(MockHTTP, :post, 3, fn _url, query, _headers ->
      if query =~ "INSERT INTO analytics.experiment_attributions" do
        Agent.update(attribution_queries, &[query | &1])
      end

      {:ok, %{status_code: 200, body: ""}}
    end)

    assert {:ok, 1} = ClickHouseUploader.upload(bundle)

    assert attribution_queries
           |> Agent.get(& &1)
           |> Enum.map(&length(Regex.scan(~r/\),\n\(/, &1)))
           |> Enum.sort() == [0, 499]
  end

  @tag capture_log: true
  test "stops attribution insertion after a failed chunk" do
    bundle = attributed_bundle(1_001, "bundle-chunk-failure")
    {:ok, request_count} = Agent.start_link(fn -> 0 end)

    expect(MockHTTP, :post, 3, fn _url, _query, _headers ->
      request_number = Agent.get_and_update(request_count, &{&1 + 1, &1 + 1})

      case request_number do
        3 -> {:ok, %{status_code: 500, body: "forced failure"}}
        _ -> {:ok, %{status_code: 200, body: ""}}
      end
    end)

    assert {:error, "Query failed with status 500: forced failure"} =
             ClickHouseUploader.upload(bundle)
  end

  defp video_statement(verb_id, result_extensions) do
    %{
      "actor" => %{
        "mbox" => "mailto:student@example.edu",
        "account" => %{
          "homePage" => "https://proton.oli.cmu.edu",
          "name" => "student@example.edu"
        }
      },
      "verb" => %{"id" => verb_id},
      "object" => %{
        "id" => "https://cdn.example.edu/video.mp4",
        "definition" => %{
          "extensions" => %{"https://w3id.org/xapi/video/extensions/length" => 90.0}
        }
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/section_id" => 111,
          "http://oli.cmu.edu/extensions/project_id" => 222,
          "http://oli.cmu.edu/extensions/publication_id" => 333,
          "http://oli.cmu.edu/extensions/page_id" => 444,
          "http://oli.cmu.edu/extensions/content_element_id" => "video-1"
        }
      },
      "result" => %{"extensions" => result_extensions},
      "timestamp" => "2026-03-27T12:00:00Z"
    }
  end

  defp attributed_part_attempt_statement do
    %{
      "actor" => %{
        "account" => %{
          "homePage" => "https://proton.oli.cmu.edu",
          "name" => "123"
        },
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "http://adlnet.gov/expapi/verbs/completed",
        "display" => %{"en-US" => "completed"}
      },
      "object" => %{
        "id" => "https://proton.oli.cmu.edu/parts/part-1",
        "definition" => %{
          "type" => "http://adlnet.gov/expapi/activities/question",
          "name" => %{"en-US" => "Part 1"}
        }
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/project_id" => 1001,
          "http://oli.cmu.edu/extensions/section_id" => 2001,
          "http://oli.cmu.edu/extensions/publication_id" => 3001,
          "http://oli.cmu.edu/extensions/activity_id" => 606,
          "http://oli.cmu.edu/extensions/part_id" => "part-1",
          "http://oli.cmu.edu/extensions/part_attempt_guid" => "part-guid",
          "http://oli.cmu.edu/extensions/experiment_attributions" => [
            %{
              "role" => "reward",
              "attribution_type" => "reward",
              "experiment_id" => 101,
              "experiment_uuid" => "11111111-2222-3333-4444-555555555555",
              "decision_point_id" => 202,
              "condition_id" => 303,
              "condition_code" => "condition-a",
              "assignment_id" => 404,
              "assignment_key" => "101:202:505",
              "enrollment_id" => 505,
              "algorithm" => "thompson_sampling",
              "policy_version" => "thompson_sampling:v2",
              "key" => "reward-key",
              "reward_source" => "activity_attempt:full_credit"
            }
          ]
        }
      },
      "result" => %{
        "score" => %{"raw" => 1.0, "min" => 0, "max" => 1},
        "extensions" => %{
          "http://oli.cmu.edu/extensions/reward_source" => "activity_attempt:full_credit"
        }
      },
      "timestamp" => "2026-07-14T12:00:00Z"
    }
  end

  defp attributed_part_attempt_json_line do
    @fixture_path
    |> File.stream!()
    |> Enum.find(&(String.trim(&1) != ""))
    |> String.trim_trailing("\n")
  end

  defp attributed_bundle(attribution_count, bundle_id) do
    statement = attributed_part_attempt_statement()

    [attribution] =
      get_in(statement, [
        "context",
        "extensions",
        "http://oli.cmu.edu/extensions/experiment_attributions"
      ])

    attributions =
      Enum.map(1..attribution_count, fn index ->
        attribution
        |> Map.put("assignment_id", index)
        |> Map.put("key", "reward-key-#{index}")
      end)

    statement =
      put_in(
        statement,
        [
          "context",
          "extensions",
          "http://oli.cmu.edu/extensions/experiment_attributions"
        ],
        attributions
      )

    %StatementBundle{body: Jason.encode!(statement), category: :attempt, bundle_id: bundle_id}
  end

  defp sha256(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end
end
