# Acceptance coverage: AC-005.
defmodule Oli.GenAI.HealthProbeTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.{HealthMonitor, HealthProbe, PoolManager, Provider}
  alias Oli.GenAI.Completions.RegisteredModel

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
      id: 73,
      adapter: :open_ai,
      base_url: "http://127.0.0.1:#{port}",
      api_key: "provider-only-key",
      organization_key: "provider-organization",
      probe_deadline_ms: 200
    }

    model = %RegisteredModel{
      id: 75,
      provider: :open_ai,
      model: "selected-probe-model",
      api_key: "legacy-key"
    }

    {:ok, origin} = Provider.origin(provider.base_url)
    spec = %{origin: origin, capacity: 1}
    :ok = PoolManager.reconcile(manager, %{{:probe, provider.id} => spec, {1, :primary} => spec})
    %{manager: manager, provider: provider, model: model}
  end

  test "real tiny inference uses Provider credentials and independent probe transport", ctx do
    {:ok, production} = PoolManager.connect(ctx.manager, {1, :primary}, ctx.provider.base_url)
    task = Task.async(fn -> HealthProbe.run(ctx.provider, ctx.model, ctx.manager) end)
    assert_receive {:request, server, headers, body}, 2_000
    assert headers =~ "provider-only-key"
    assert headers =~ "provider-organization"
    refute headers =~ "legacy-key"

    assert %{
             "model" => "selected-probe-model",
             "max_tokens" => 8,
             "stream" => false,
             "messages" => [%{"role" => "user", "content" => "Reply with OK."}]
           } = Jason.decode!(body)

    send(server, {:respond, 200, valid_body()})
    assert :ok = Task.await(task, 2_000)
    assert PoolManager.snapshot(ctx.manager).pools[{1, :primary}].current.checked_out == 1
    :hackney.close(production)

    eventually(fn ->
      PoolManager.snapshot(ctx.manager).pools[{:probe, ctx.provider.id}].current.checked_out == 0
    end)
  end

  test "probe realizes model and credential endpoint templates exactly like the ordinary adapter",
       ctx do
    provider = %{
      ctx.provider
      | base_url: ctx.provider.base_url <> "/deployments/:model/:api_key/:secondary_api_key"
    }

    task = Task.async(fn -> HealthProbe.run(provider, ctx.model, ctx.manager) end)
    assert_receive {:request, server, headers, _}, 2_000

    assert headers =~
             "POST /deployments/selected-probe-model/provider-only-key/provider-organization/v1/chat/completions "

    send(server, {:respond, 200, valid_body()})
    assert :ok = Task.await(task, 2_000)
  end

  test "HTTP and malformed completion failures return safe categories", ctx do
    for {status, body, expected} <- [
          {429, ~s({"error":"sensitive-provider-payload"}), :rate_limited},
          {200, ~s({"choices":[]}), :invalid_completion},
          {503, "sensitive", :upstream_unavailable}
        ] do
      task = Task.async(fn -> HealthProbe.run(ctx.provider, ctx.model, ctx.manager) end)
      assert_receive {:request, server, _, _}, 2_000
      send(server, {:respond, status, body})
      assert {:error, ^expected} = Task.await(task, 2_000)
    end
  end

  test "a real probe deadline kills the request and reclaims transport capacity", ctx do
    tasks = start_supervised!({Task.Supervisor, max_children: 1})
    provider = %{ctx.provider | probe_deadline_ms: 80}

    monitor =
      start_supervised!(
        {HealthMonitor,
         config: %{provider: provider, model: ctx.model, enabled: true},
         task_supervisor: tasks,
         probe: fn p, m -> HealthProbe.run(p, m, ctx.manager) end,
         jitter_ms: 0}
      )

    assert_receive {:request, _server, _, _}, 2_000
    eventually(fn -> HealthMonitor.snapshot(monitor).failure_category == :deadline_exceeded end)

    eventually(fn ->
      PoolManager.snapshot(ctx.manager).pools[{:probe, provider.id}].current.checked_out == 0
    end)
  end

  test "a bounded response prefix cannot masquerade as a complete oversized inference", ctx do
    task = Task.async(fn -> HealthProbe.run(ctx.provider, ctx.model, ctx.manager) end)
    assert_receive {:request, server, _, _}, 2_000
    send(server, {:respond, 200, valid_body() <> String.duplicate(" ", 65_536)})
    assert {:error, :response_too_large} = Task.await(task, 2_000)

    eventually(fn ->
      PoolManager.snapshot(ctx.manager).pools[{:probe, ctx.provider.id}].current.checked_out == 0
    end)
  end

  test "missing or deferred configuration never performs network work", ctx do
    assert {:configuration_error, :missing_probe_model} =
             HealthProbe.run(ctx.provider, nil, ctx.manager)

    assert {:configuration_error, :missing_credentials} =
             HealthProbe.run(%{ctx.provider | api_key: nil}, ctx.model, ctx.manager)

    assert {:configuration_error, :unsupported_probe_adapter} =
             HealthProbe.run(%{ctx.provider | adapter: :claude}, ctx.model, ctx.manager)

    refute_receive {:request, _, _, _}, 30
  end

  defp valid_body,
    do:
      Jason.encode!(%{
        choices: [%{finish_reason: "stop", message: %{content: "Any successful text"}}]
      })

  defp accept(listener, parent) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        pid =
          spawn_link(fn ->
            receive do
              :ready -> serve(socket, parent)
            end
          end)

        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :ready)
        accept(listener, parent)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket, parent) do
    case read_headers(socket, "") do
      {:ok, headers, body} ->
        [_, length] = Regex.run(~r/content-length:\s*(\d+)/i, headers)
        missing = String.to_integer(length) - byte_size(body)

        rest =
          case missing > 0 do
            true ->
              case :gen_tcp.recv(socket, missing, 2_000) do
                {:ok, bytes} -> bytes
                _ -> ""
              end

            false ->
              ""
          end

        send(parent, {:request, self(), headers, body <> rest})

        receive do
          {:respond, status, response} ->
            :gen_tcp.send(
              socket,
              "HTTP/1.1 #{status} Response\r\ncontent-type: application/json\r\ncontent-length: #{byte_size(response)}\r\nconnection: close\r\n\r\n#{response}"
            )
        after
          2_000 -> :ok
        end

      _ ->
        :ok
    end

    :gen_tcp.close(socket)
  end

  defp read_headers(socket, buffer) do
    case :binary.split(buffer, "\r\n\r\n") do
      [headers, body] ->
        {:ok, headers, body}

      _ ->
        case :gen_tcp.recv(socket, 0, 2_000) do
          {:ok, bytes} -> read_headers(socket, buffer <> bytes)
          error -> error
        end
    end
  end

  defp eventually(fun, attempts \\ 100)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    case fun.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        eventually(fun, attempts - 1)
    end
  end
end
