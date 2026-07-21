defmodule Oli.Analytics.XAPI.SchemaValidatorTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.XAPI.SchemaValidator

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "xapi_schema_validator_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "validates a JSONL file and classifies invalid json and schema mismatch rows", %{
    tmp_dir: tmp_dir
  } do
    file_path = Path.join(tmp_dir, "sample.jsonl")

    valid_statement = %{
      "actor" => %{
        "account" => %{"homePage" => "torus.example.edu", "name" => 89273},
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "http://adlnet.gov/expapi/verbs/completed",
        "display" => %{"en-US" => "completed"}
      },
      "object" => %{
        "id" => "torus.example.edu/page_attempt/abc}",
        "definition" => %{
          "name" => %{"en-US" => "Page Attempt"},
          "type" => "http://oli.cmu.edu/extensions/page_attempt"
        },
        "objectType" => "Activity"
      },
      "result" => %{
        "score" => %{"scaled" => 1.0, "raw" => 1.0, "min" => 0, "max" => 1.0},
        "completion" => true,
        "success" => true
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/page_attempt_number" => 1,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => "abc",
          "http://oli.cmu.edu/extensions/section_id" => 5515,
          "http://oli.cmu.edu/extensions/project_id" => 2788,
          "http://oli.cmu.edu/extensions/publication_id" => 13771,
          "http://oli.cmu.edu/extensions/page_id" => 416_784
        }
      },
      "timestamp" => "2025-10-17T22:22:11Z"
    }

    schema_mismatch_statement =
      valid_statement
      |> put_in(["verb", "id"], "http://adlnet.gov/expapi/verbs/completed")
      |> put_in(["object", "definition", "type"], "http://oli.cmu.edu/extensions/page_attempt")
      |> update_in(
        ["context", "extensions"],
        &Map.delete(&1, "http://oli.cmu.edu/extensions/page_id")
      )

    invalid_json = ~s({"actor":{"account":{"homePage":"torus.example.edu","name":89273}})

    content =
      [
        Jason.encode!(valid_statement),
        invalid_json,
        Jason.encode!(schema_mismatch_statement)
      ]
      |> Enum.join("\n")

    File.write!(file_path, content)

    assert {:ok, summary} = SchemaValidator.validate_paths([file_path])

    assert summary.file_count == 1
    assert summary.total_lines == 3
    assert summary.valid_lines == 1
    assert summary.invalid_json_lines == 1
    assert summary.schema_mismatch_lines == 1
    assert summary.error_count == 2

    [file] = summary.files
    assert file.path == file_path
    assert file.total_lines == 3
    assert file.valid_lines == 1
    assert file.invalid_json_lines == 1
    assert file.schema_mismatch_lines == 1
    assert Enum.any?(file.errors, &(&1.classification == :invalid_json and &1.line == 2))
    assert Enum.any?(file.errors, &(&1.classification == :schema_mismatch and &1.line == 3))
  end

  test "validates host statements with experiment attribution arrays", %{tmp_dir: tmp_dir} do
    file_path = Path.join(tmp_dir, "experiment.jsonl")

    statement = %{
      "actor" => %{
        "account" => %{"homePage" => "https://proton.oli.cmu.edu", "name" => "123"},
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "http://adlnet.gov/expapi/verbs/completed",
        "display" => %{"en-US" => "completed"}
      },
      "object" => %{
        "id" => "https://proton.oli.cmu.edu/page_attempt/abc",
        "definition" => %{
          "type" => "http://oli.cmu.edu/extensions/page_attempt",
          "name" => %{"en-US" => "Page Attempt"}
        },
        "objectType" => "Activity"
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/project_id" => 1001,
          "http://oli.cmu.edu/extensions/section_id" => 2001,
          "http://oli.cmu.edu/extensions/publication_id" => 3001,
          "http://oli.cmu.edu/extensions/page_id" => 7001,
          "http://oli.cmu.edu/extensions/page_attempt_number" => 1,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => "abc",
          "http://oli.cmu.edu/extensions/experiment_attributions" => [
            %{
              "role" => "rollup",
              "experiment_id" => 101,
              "decision_point_id" => 202,
              "condition_id" => 303,
              "condition_code" => "condition-a",
              "assignment_id" => 404,
              "assignment_key" => "101:202:505",
              "idempotency_key" => "rollup-key"
            }
          ]
        }
      },
      "result" => %{
        "score" => %{"scaled" => 1.0, "raw" => 1.0, "min" => 0, "max" => 1.0},
        "completion" => true,
        "success" => true
      },
      "timestamp" => "2026-07-14T12:00:00Z"
    }

    File.write!(file_path, Jason.encode!(statement))

    assert {:ok, summary} = SchemaValidator.validate_paths([file_path])
    assert summary.valid_lines == 1
    assert summary.error_count == 0
  end

  test "rejects retired dedicated experiment event statements", %{tmp_dir: tmp_dir} do
    file_path = Path.join(tmp_dir, "experiment_event.jsonl")

    statement = %{
      "actor" => %{
        "account" => %{"homePage" => "https://proton.oli.cmu.edu", "name" => "123"},
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "http://oli.cmu.edu/extensions/verbs/experiment_reward_recorded",
        "display" => %{"en-US" => "recorded experiment reward"}
      },
      "object" => %{
        "id" => "https://proton.oli.cmu.edu/experiments/101",
        "definition" => %{
          "type" => "http://oli.cmu.edu/extensions/types/experiment_event",
          "name" => %{"en-US" => "experiment_reward_recorded"}
        }
      },
      "context" => %{"extensions" => %{}},
      "timestamp" => "2026-07-14T12:00:00Z"
    }

    File.write!(file_path, Jason.encode!(statement))

    assert {:ok, summary} = SchemaValidator.validate_paths([file_path])
    assert summary.valid_lines == 0
    assert summary.schema_mismatch_lines == 1
  end
end
