defmodule OliWeb.Api.VariableEvaluationControllerTest do
  use OliWeb.ConnCase, async: false

  import Mox

  setup :verify_on_exit!
  setup :register_and_log_in_author

  setup do
    original_variable_substitution = Application.get_env(:oli, :variable_substitution)
    original_http_client = Application.get_env(:oli, :http_client)
    original_aws_client = Application.get_env(:oli, :aws_client)

    on_exit(fn ->
      restore_env(:variable_substitution, original_variable_substitution)
      restore_env(:http_client, original_http_client)
      restore_env(:aws_client, original_aws_client)
    end)

    :ok
  end

  test "returns evaluations through LambdaImpl while preserving legacy count behavior", %{
    conn: conn
  } do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: Oli.Activities.Transformers.VariableSubstitution.LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{} = operation,
                                          [region: "us-east-1"] ->
      assert operation.path == "/2015-03-31/functions/eval-engine/invocations?"

      assert operation.data == %{
               vars: [[%{"variable" => "V1", "expression" => "1 + 1"}]],
               count: 1
             }

      {:ok, [[%{"variable" => "V1", "result" => 2, "errored" => false}]]}
    end)

    conn =
      post(conn, "/api/v1/variables/", %{
        "data" => [%{"variable" => "V1", "expression" => "1 + 1"}],
        "count" => 99
      })

    assert %{
             "result" => "success",
             "evaluations" => [%{"variable" => "V1", "result" => 2, "errored" => false}]
           } = json_response(conn, 200)
  end

  test "returns server error when LambdaImpl fails", %{conn: conn} do
    Application.put_env(:oli, :aws_client, Oli.Test.MockAws)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: Oli.Activities.Transformers.VariableSubstitution.LambdaImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://localhost:8000/sandbox"
    )

    expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.JSON{}, [region: "us-east-1"] ->
      {:ok, %{"error" => %{"type" => "runtime_error", "message" => "failed"}}}
    end)

    conn =
      post(conn, "/api/v1/variables/", %{
        "data" => [%{"variable" => "V1", "expression" => "1 + 1"}],
        "count" => 1
      })

    assert response(conn, 500) == "server error"
  end

  test "returns evaluations through RestImpl for rollback", %{conn: conn} do
    Application.put_env(:oli, :http_client, Oli.Test.MockHTTP)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: Oli.Activities.Transformers.VariableSubstitution.RestImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://authoring-eval.test/sandbox"
    )

    expect(Oli.Test.MockHTTP, :post, fn url, body, headers, [] ->
      assert url == "http://authoring-eval.test/sandbox"
      assert headers == ["Content-Type": "application/json"]

      assert Jason.decode!(body) == %{
               "vars" => [[%{"variable" => "V1", "expression" => "1 + 1"}]],
               "count" => 1
             }

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: Poison.encode!([[%{"variable" => "V1", "result" => 2, "errored" => false}]])
       }}
    end)

    conn =
      post(conn, "/api/v1/variables/", %{
        "data" => [%{"variable" => "V1", "expression" => "1 + 1"}],
        "count" => 5
      })

    assert %{
             "result" => "success",
             "evaluations" => [%{"variable" => "V1", "result" => 2, "errored" => false}]
           } = json_response(conn, 200)
  end

  test "returns server error when RestImpl fails", %{conn: conn} do
    Application.put_env(:oli, :http_client, Oli.Test.MockHTTP)

    Application.put_env(:oli, :variable_substitution,
      dispatcher: Oli.Activities.Transformers.VariableSubstitution.RestImpl,
      aws_fn_name: "eval-engine",
      aws_region: "us-east-1",
      rest_endpoint_url: "http://authoring-eval.test/sandbox"
    )

    expect(Oli.Test.MockHTTP, :post, fn "http://authoring-eval.test/sandbox",
                                        _body,
                                        _headers,
                                        [] ->
      {:error, :econnrefused}
    end)

    conn =
      post(conn, "/api/v1/variables/", %{
        "data" => [%{"variable" => "V1", "expression" => "1 + 1"}],
        "count" => 1
      })

    assert response(conn, 500) == "server error"
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)
end
