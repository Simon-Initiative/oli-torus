defmodule Oli.Analytics.XAPI.ClickHouseUploaderTest do
  use ExUnit.Case, async: true

  import Mox

  alias Oli.Analytics.XAPI.ClickHouseUploader
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Test.MockHTTP

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
end
