defmodule Oli.GenAI.Completions.ManagedOpenAITest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{PoolManager, Provider, RoutingPlan}
  alias Oli.GenAI.Completions.{ManagedOpenAI, Message, RegisteredModel}

  setup do
    manager = start_supervised!({PoolManager, name: nil, namespace: make_ref(), poll_ms: 10})
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    server = spawn_link(fn -> accept(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      Process.unlink(server)
      Process.exit(server, :kill)
    end)

    provider = %Provider{
      id: 91,
      adapter: :open_ai,
      base_url: "http://127.0.0.1:#{port}",
      api_key: "provider-only-key",
      organization_key: nil
    }

    {:ok, origin} = Provider.origin(provider.base_url)
    :ok = PoolManager.reconcile(manager, %{{:managed, 91} => %{origin: origin, capacity: 1}})
    {:ok, pool} = PoolManager.lookup(manager, {:managed, 91})

    plan = %RoutingPlan{
      selected_model: %RegisteredModel{id: 92, provider_id: 91, model: "selected-model"},
      provider: provider,
      pool: pool,
      tier: :administrative,
      request_type: :generate
    }

    %{plan: plan}
  end

  describe "token limit parameter" do
    test "a Provider on an OpenAI API host receives the caller's budget as max_completion_tokens",
         %{plan: plan} do
      openai_api_hosts(["127.0.0.1"])

      body = request_body(plan, max_tokens: 2000)

      assert body["max_completion_tokens"] == 2000
      refute Map.has_key?(body, "max_tokens")
    end

    test "an OpenAI-compatible server keeps receiving max_tokens", %{plan: plan} do
      openai_api_hosts(["api.openai.com"])

      body = request_body(plan, max_tokens: 2000)

      assert body["max_tokens"] == 2000
      refute Map.has_key?(body, "max_completion_tokens")
    end
  end

  @error_json ~s({"error":{"message":"length-canary"}})
  @unframed_error_responses [
    {"two content-length headers",
     "content-length: 10\r\ncontent-length: #{byte_size(@error_json)}\r\nconnection: close\r\n\r\n" <>
       @error_json},
    {"content-length beside chunked encoding",
     "content-length: 10\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n" <>
       Integer.to_string(byte_size(@error_json), 16) <> "\r\n" <> @error_json <> "\r\n0\r\n\r\n"},
    {"a second content-length whose name carries spaces",
     "content-length: 10\r\ncontent-length : #{byte_size(@error_json)}\r\nconnection: close\r\n\r\n" <>
       @error_json},
    {"a transfer-encoding whose name carries spaces",
     "content-length: 10\r\ntransfer-encoding : chunked\r\nconnection: close\r\n\r\n" <>
       Integer.to_string(byte_size(@error_json), 16) <> "\r\n" <> @error_json <> "\r\n0\r\n\r\n"},
    {"a negative content-length",
     "content-length: -1\r\nconnection: close\r\n\r\n" <> @error_json},
    {"a declared length over the limit whose bytes never arrive", "content-length: 70000\r\n\r\n"}
  ]

  describe "failed responses" do
    for {shape, rest} <- @unframed_error_responses do
      test "an error body with #{shape} is not read", %{plan: plan} do
        task =
          Task.async(fn ->
            ManagedOpenAI.request(
              :generate,
              [%Message{role: :user, content: "hello"}],
              [],
              plan,
              nil,
              deadline: System.monotonic_time(:millisecond) + 2_000,
              capture_provider_message: true
            )
          end)

        assert_receive {:request, server, _}, 2_000
        send(server, {:reply_raw, "HTTP/1.1 400 Bad Request\r\n" <> unquote(rest)})
        assert {:error, %{http_status: 400} = error} = Task.await(task, 2_000)
        refute Map.has_key?(error, :provider_message)
      end
    end

    test "a production error is returned without reading its body", %{plan: plan} do
      messages = [%Message{role: :user, content: "hello"}]

      task =
        Task.async(fn ->
          ManagedOpenAI.request(:generate, messages, [], plan, nil,
            deadline: System.monotonic_time(:millisecond) + 5_000
          )
        end)

      assert_receive {:request, server, _}, 2_000
      send(server, {:reply_raw, "HTTP/1.1 400 Bad Request\r\ncontent-length: 50\r\n\r\n"})

      assert Task.await(task, 1_000) == {:error, %{http_status: 400, error_category: :http_error}}
    end

    test "an oversized error body is never left on a connection that serves the next request",
         %{plan: plan} do
      messages = [%Message{role: :user, content: "hello"}]

      admin =
        Task.async(fn ->
          ManagedOpenAI.request(:generate, messages, [], plan, nil,
            deadline: System.monotonic_time(:millisecond) + 2_000,
            capture_provider_message: true
          )
        end)

      assert_receive {:request, server, _}, 2_000
      send(server, {:reply_chunked_unfinished, 400, String.duplicate("x", 70_000)})
      assert {:error, %{http_status: 400} = error} = Task.await(admin)
      refute Map.has_key?(error, :provider_message)

      production =
        Task.async(fn ->
          ManagedOpenAI.request(:generate, messages, [], plan, nil,
            deadline: System.monotonic_time(:millisecond) + 2_000
          )
        end)

      assert_receive {:request, server, _}, 2_000
      send(server, {:reply, 200, Jason.encode!(%{choices: [%{message: %{content: "OK"}}]})})
      assert {:ok, "OK"} = Task.await(production)
    end
  end

  defp openai_api_hosts(hosts) do
    previous = Application.fetch_env(:oli, :genai_max_completion_tokens_hosts)
    Application.put_env(:oli, :genai_max_completion_tokens_hosts, hosts)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:oli, :genai_max_completion_tokens_hosts, value)
        :error -> Application.delete_env(:oli, :genai_max_completion_tokens_hosts)
      end
    end)
  end

  defp request_body(plan, opts) do
    deadline = System.monotonic_time(:millisecond) + 2_000
    messages = [%Message{role: :user, content: "hello"}]

    task =
      Task.async(fn ->
        ManagedOpenAI.request(:generate, messages, [], plan, nil, [deadline: deadline] ++ opts)
      end)

    assert_receive {:request, server, request}, 2_000
    send(server, {:reply, 200, Jason.encode!(%{choices: [%{message: %{content: "OK"}}]})})
    assert {:ok, "OK"} = Task.await(task)
    [_headers, body] = :binary.split(request, "\r\n\r\n")
    Jason.decode!(body)
  end

  defp accept(listener, owner) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        worker =
          spawn_link(fn ->
            receive do
              :ready -> serve(socket, owner, "", "")
            end
          end)

        :ok = :gen_tcp.controlling_process(socket, worker)
        send(worker, :ready)
        accept(listener, owner)

      {:error, :closed} ->
        :ok
    end
  end

  # `pending` holds response bytes withheld from the previous reply on this connection; they are
  # sent ahead of the next reply, as a slow server would deliver them.
  defp serve(socket, owner, buffer, pending) do
    # Read the complete JSON body before making the request observable to the test.
    case :binary.split(buffer, "\r\n\r\n") do
      [headers, body] ->
        [_, size] = Regex.run(~r/content-length:\s*(\d+)/i, headers)

        case byte_size(body) >= String.to_integer(size) do
          true ->
            send(owner, {:request, self(), buffer})
            respond(socket, owner, pending)

          false ->
            read_request(socket, owner, buffer, pending)
        end

      _ ->
        read_request(socket, owner, buffer, pending)
    end
  end

  defp read_request(socket, owner, buffer, pending) do
    case :gen_tcp.recv(socket, 0, 3_000) do
      {:ok, bytes} -> serve(socket, owner, buffer <> bytes, pending)
      _ -> :gen_tcp.close(socket)
    end
  end

  defp respond(socket, owner, pending) do
    receive do
      {:reply, status, body} ->
        :gen_tcp.send(
          socket,
          pending <>
            "HTTP/1.1 #{status} Response\r\ncontent-length: #{byte_size(body)}\r\nconnection: close\r\n\r\n#{body}"
        )

        :gen_tcp.close(socket)

      {:reply_chunked_unfinished, status, body} ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 #{status} Response\r\ntransfer-encoding: chunked\r\n\r\n" <>
            Integer.to_string(byte_size(body), 16) <> "\r\n" <> body <> "\r\n"
        )

        read_request(socket, owner, "", "0\r\n\r\n")

      # Raw bytes, then the connection stays open until the next request or the read timeout.
      {:reply_raw, response} ->
        :gen_tcp.send(socket, response)
        read_request(socket, owner, "", "")
    after
      3_000 -> :gen_tcp.close(socket)
    end
  end
end
