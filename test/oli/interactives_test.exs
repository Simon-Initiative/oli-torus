defmodule Oli.InteractivesTest do
  use ExUnit.Case, async: true

  import Mox

  alias HTTPoison.Response
  alias Oli.Interactives
  alias Oli.Interactives.AgentsClient
  alias Oli.Test.MockHTTP

  setup :verify_on_exit!

  defp opts, do: [api_key: "test-secret", http_client: MockHTTP]

  test "starts a hosted session with minimal tooling, inline setup checks and no sandbox credentials" do
    expect(MockHTTP, :request, fn :post, url, body, headers, options ->
      assert url == "https://api.openai.com/v1/agents/sessions"
      assert headers |> Map.new() |> Map.get("authorization") == "Bearer test-secret"
      assert headers |> Map.new() |> Map.get("openai-beta") == "agents=v1"
      assert options[:follow_redirect] == false

      request = Jason.decode!(body)
      assert request["stream"] == false
      assert request["input"] == "Make a chemistry lab"
      assert request["agent"]["model"] == "test-model"
      assert request["environment"]["type"] == "openai_hosted"
      refute Map.has_key?(request["environment"], "env")
      assert List.last(request["environment"]["setup_commands"])["command"] =~ "verify.cjs"

      files = Map.new(request["environment"]["files"], &{&1["path"], Base.decode64!(&1["data"])})
      package = Jason.decode!(files["/workspace/package.json"])
      assert Map.keys(package["devDependencies"]) |> Enum.sort() == ["esbuild", "playwright"]
      assert files["/workspace/torus-tools/verify.cjs"] =~ "chromium.launch"
      assert files["/workspace/torus-tools/torus.js"] =~ "TorusInteractive"
      assert files["/workspace/torus-tools/DELIVERY_API.md"] =~ "parts.finalize"

      for name <- ["build-interactive", "revise-interactive"] do
        skill = files["/workspace/.agents/skills/#{name}/SKILL.md"]

        assert skill ==
                 File.read!(
                   Application.app_dir(:oli, "priv/interactives/skills/#{name}/SKILL.md")
                 )

        for [_, reference] <- Regex.scan(~r/\]\(([^)]+\.md)\)/, skill) do
          reference_path = Path.expand(reference, "/workspace/.agents/skills/#{name}")

          assert is_binary(files[reference_path]),
                 "Missing hosted skill reference: #{reference_path}"
        end
      end

      assert files["/workspace/.agents/skills/references/delivery-api.md"] ==
               files["/workspace/torus-tools/DELIVERY_API.md"]

      assert files["/workspace/.agents/skills/references/authoring-contract.md"] =~
               "finish_interactive"

      assert request["agent"]["instructions"] =~
               "/workspace/.agents/skills/build-interactive/SKILL.md"

      {:ok, %Response{status_code: 200, body: ~s({"id":"sess_1","status":"idle"})}}
    end)

    assert {:ok, %{"id" => "sess_1"}} =
             Interactives.start_session(
               "Make a chemistry lab",
               Keyword.put(opts(), :model, "test-model")
             )
  end

  test "rejects absent credentials, empty prompts and non-hosted environments without HTTP" do
    assert {:error, %{kind: :configuration}} = Interactives.start_session(" ", opts())

    assert {:error, %{kind: :configuration}} =
             Interactives.start_session("Build", Keyword.put(opts(), :api_key, nil))

    assert {:error, %{kind: :configuration}} =
             AgentsClient.start_session(%{"environment" => %{"type" => "self_hosted"}}, opts())

    assert {:error, %{kind: :configuration}} = AgentsClient.get_session(nil, opts())
  end

  test "provider errors and timeouts remain private and ambiguous creations are not retried" do
    expect(MockHTTP, :request, fn _, _, _, _, _ ->
      {:ok,
       %Response{
         status_code: 503,
         body: "test-secret and private prompt",
         headers: [{"X-Request-ID", "req_1"}]
       }}
    end)

    assert {:error, %{kind: :http, request_id: "req_1", creation_uncertain: true} = error} =
             Interactives.start_session("private prompt", opts())

    refute inspect(error) =~ "test-secret"
    refute inspect(error) =~ "private prompt"

    expect(MockHTTP, :request, fn _, _, _, _, _ ->
      {:error, %HTTPoison.Error{reason: :timeout}}
    end)

    assert {:error, %{kind: :transport, creation_uncertain: true}} =
             Interactives.start_session("Build", opts())

    expect(MockHTTP, :request, fn _, _, _, _, _ ->
      {:ok, %Response{status_code: 200, body: "invalid JSON"}}
    end)

    assert {:error, %{kind: :protocol, creation_uncertain: false}} =
             AgentsClient.get_session("sess_1", opts())
  end

  test "preserves read pagination and uses the provider's continuation, cancellation and cleanup contracts" do
    expect(MockHTTP, :request, fn :get, url, "", _, _ ->
      assert url =~ "/sessions/sess_1/items?"
      assert URI.decode_query(URI.parse(url).query)["after"] == "cursor/+%"

      {:ok,
       %Response{status_code: 200, body: ~s({"data":[],"has_more":true,"last_id":"cursor_2"})}}
    end)

    assert {:ok, %{"has_more" => true, "last_id" => "cursor_2"}} =
             AgentsClient.items_page("sess_1", "cursor/+%", opts())

    expect(MockHTTP, :request, fn :post, url, body, headers, _ ->
      assert url =~ "/sessions/sess_1/events"
      assert {"idempotency-key", "input_1"} in headers
      [event] = Jason.decode!(body)["events"]
      assert event["type"] == "agent.session.input.message"
      assert get_in(event, ["input", Access.at(0), "content", Access.at(0), "text"]) == "Continue"
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    assert {:ok, %{}} =
             AgentsClient.submit_input(
               "sess_1",
               "Continue",
               Keyword.put(opts(), :idempotency_key, "input_1")
             )

    expect(MockHTTP, :request, fn :post, _, body, _, _ ->
      assert Jason.decode!(body) == %{"events" => [%{"type" => "agent.session.input.cancel"}]}
      {:ok, %Response{status_code: 202, body: ""}}
    end)

    assert {:ok, %{}} = AgentsClient.cancel_session("sess_1", opts())

    expect(MockHTTP, :request, fn :delete, url, "", _, _ ->
      assert url =~ "/sessions/sess_1"
      {:ok, %Response{status_code: 200, body: ~s({"deleted":true})}}
    end)

    assert {:ok, %{"deleted" => true}} = AgentsClient.delete_session("sess_1", opts())
  end
end
