defmodule Oli.Activities.Transformers.VariableSubstitutionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox
  alias Oli.Activities.Transformers.VariableSubstitution
  alias Oli.Activities.Transformers.VariableSubstitution.LambdaImpl
  alias Oli.Activities.Model.Transformation

  @invoke_event [:oli, :eval_engine, :lambda, :invoke]
  @decode_event [:oli, :eval_engine, :lambda, :decode]

  setup :verify_on_exit!

  setup do
    original_variable_substitution = Application.get_env(:oli, :variable_substitution)
    original_aws_client = Application.get_env(:oli, :aws_client)

    on_exit(fn ->
      restore_env(:variable_substitution, original_variable_substitution)
      restore_env(:aws_client, original_aws_client)
    end)

    :ok
  end

  test "correctly escapes and replaces variables that possibly contain JSON special chars" do
    model = %{
      "stem" => "var1 = @@var1@@",
      "choices" => [
        %{id: "1", content: []},
        %{id: "2", content: []},
        %{id: "3", content: []},
        %{id: "4", content: []}
      ],
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ],
        "transformations" => [
          %{"id" => "1", "path" => "choices", "operation" => "shuffle"}
        ]
      }
    }

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => "evaluated"}
      ])

    assert transformed["stem"] == "var1 = evaluated"

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => ~s|"|}
      ])

    assert transformed["stem"] == ~s|var1 = "|

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => ~s|1\n2|}
      ])

    assert transformed["stem"] == ~s|var1 = 1\n2|

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => [0, 1, 2]}
      ])

    assert transformed["stem"] == ~s|var1 = [0, 1, 2]|

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => " 22"}
      ])

    assert transformed["stem"] == ~s|var1 = 22|
  end

  test "LambdaImpl substitutes variables using the common replacement path" do
    model = %{"stem" => "var1 = @@var1@@"}

    assert {:ok, %{"stem" => "var1 = evaluated"}} =
             LambdaImpl.substitute(model, [%{"variable" => "var1", "result" => "evaluated"}])
  end

  test "LambdaImpl invokes AWS and decodes successful responses" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-west-2",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{} = operation, opts ->
      assert operation.service == :lambda
      assert operation.path == "/2015-03-31/functions/eval-engine/invocations?"

      assert operation.data == %{
               vars: [[%{"variable" => "V1", "expression" => "1 + 1"}]],
               count: 1
             }

      assert opts == [region: "us-west-2"]

      {:ok, [[%{"variable" => "V1", "result" => 2, "errored" => false}]]}
    end)

    assert {:ok, [[%{"variable" => "V1", "result" => 2, "errored" => false}]]} =
             LambdaImpl.provide_batch_context([
               %Transformation{
                 id: 1,
                 data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                 operation: :variable_substitution
               }
             ])
  end

  test "LambdaImpl returns AWS invocation failures" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:error, :timeout}
    end)

    assert {:error, :timeout} =
             LambdaImpl.provide_batch_context([
               %Transformation{
                 id: 1,
                 data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                 operation: :variable_substitution
               }
             ])
  end

  test "LambdaImpl returns payload decode failures" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:ok, %{body: "not-json"}}
    end)

    assert {:error, %Jason.DecodeError{}} =
             LambdaImpl.provide_batch_context([
               %Transformation{
                 id: 1,
                 data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                 operation: :variable_substitution
               }
             ])
  end

  test "LambdaImpl rejects malformed payloads" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:ok, [%{"variable" => "V1", "result" => 2, "errored" => false}]}
    end)

    assert {:error, "Error retrieving the payload"} =
             LambdaImpl.provide_batch_context([
               %Transformation{
                 id: 1,
                 data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                 operation: :variable_substitution
               }
             ])
  end

  test "LambdaImpl emits sanitized telemetry and logs for successful invocations" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:ok, [[%{"variable" => "V1", "result" => 2, "errored" => false}]]}
    end)

    handler_id = unique_handler_id()
    attach_telemetry(handler_id, [@invoke_event, @decode_event])

    assert {:ok, [[%{"variable" => "V1", "result" => 2, "errored" => false}]]} =
             LambdaImpl.provide_batch_context([
               %Transformation{
                 id: 1,
                 data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                 operation: :variable_substitution
               }
             ])

    assert_receive {:telemetry_event, @invoke_event, %{duration_ms: invoke_duration_ms},
                    invoke_meta}

    assert is_integer(invoke_duration_ms)
    assert invoke_meta.outcome == :ok
    assert invoke_meta.error_category == nil
    assert invoke_meta.function_name == "eval-engine"
    assert invoke_meta.region == "us-east-1"
    assert invoke_meta.request_batch_count == 1
    assert invoke_meta.request_variable_count == 1
    refute Map.has_key?(invoke_meta, :vars)
    refute Map.has_key?(invoke_meta, :evaluations)

    assert_receive {:telemetry_event, @decode_event, %{duration_ms: decode_duration_ms},
                    decode_meta}

    assert is_integer(decode_duration_ms)
    assert decode_meta.outcome == :ok
    assert decode_meta.error_category == nil
    assert decode_meta.response_descriptor == :decoded_list
    assert decode_meta.request_batch_count == 1
    assert decode_meta.request_variable_count == 1

    :telemetry.detach(handler_id)
  end

  test "LambdaImpl emits error telemetry without leaking payload data on invoke failures" do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:error, :timeout}
    end)

    handler_id = unique_handler_id()
    attach_telemetry(handler_id, [@invoke_event, @decode_event])

    log =
      capture_log([level: :warning], fn ->
        assert {:error, :timeout} =
                 LambdaImpl.provide_batch_context([
                   %Transformation{
                     id: 1,
                     data: [%{"variable" => "V1", "expression" => "1 + 1"}],
                     operation: :variable_substitution
                   }
                 ])
      end)

    assert_receive {:telemetry_event, @invoke_event, %{duration_ms: duration_ms}, invoke_meta}
    assert is_integer(duration_ms)
    assert invoke_meta.outcome == :error
    assert invoke_meta.error_category == :timeout
    assert invoke_meta.request_batch_count == 1
    assert invoke_meta.request_variable_count == 1

    refute_receive {:telemetry_event, @decode_event, _, _}

    assert log =~ "Variable substitution Lambda invocation failed"
    refute log =~ "1 + 1"

    :telemetry.detach(handler_id)
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)

  defp unique_handler_id do
    "variable-substitution-telemetry-test-#{System.unique_integer([:positive])}"
  end

  defp attach_telemetry(handler_id, events) do
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )
  end
end
