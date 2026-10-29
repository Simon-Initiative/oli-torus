defmodule Oli.GenAI.PrimaryOnlyTest do
  use Oli.DataCase, async: false

  alias Oli.GenAI
  alias Oli.GenAI.{Execution, PoolManager, PrimaryOnly, Router, TransportPool}
  alias Oli.GenAI.Completions.Message

  setup do
    previous = Application.fetch_env(:oli, :genai_routing_primary_only)
    Application.put_env(:oli, :genai_routing_primary_only, true)

    on_exit(fn ->
      PoolManager.reconcile(PrimaryOnly, %{})

      case previous do
        {:ok, value} -> Application.put_env(:oli, :genai_routing_primary_only, value)
        :error -> Application.delete_env(:oli, :genai_routing_primary_only)
      end
    end)

    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    server = spawn_link(fn -> accept(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      Process.unlink(server)
      Process.exit(server, :kill)
    end)

    {:ok, provider} =
      GenAI.create_provider(%{
        name: "Emergency",
        adapter: :open_ai,
        api_key: "secret",
        base_url: "http://127.0.0.1:#{port}"
      })

    {:ok, model} =
      GenAI.create_registered_model(%{
        name: "Primary",
        model: "primary",
        provider_id: provider.id
      })

    {:ok, config} =
      GenAI.create_service_config(%{
        name: "Emergency",
        primary_model_id: model.id,
        primary_pool_capacity: 1
      })

    %{config: config, provider: provider, model: model, ctx: %{runtime: :missing_runtime}}
  end

  test "fresh primary selection ignores unavailable runtime and invalid secondary configuration",
       c do
    # Bypass context validation to simulate broken tier configuration in production.
    Repo.update!(Ecto.Changeset.change(c.config, secondary_model_id: c.model.id))
    assert {:ok, plan} = Router.route(c.ctx, c.config)
    assert plan.reason == :kill_switch_primary_only
    assert plan.selected_model.id == c.model.id
    assert {:error, :primary_only} = Router.backup(c.ctx, c.config, c.provider.id)
    assert GenAI.Diagnostics.snapshot(:missing_runtime, :missing_manager).primary_only

    task = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config) end)
    assert_receive {:request, server, headers}, 2000
    assert headers =~ "Bearer secret"
    assert headers =~ ~s("model":"primary")
    send(server, {:reply, 200, Jason.encode!(%{choices: [%{message: %{content: "working"}}]})})
    assert {:ok, "working"} = Task.await(task)

    Application.put_env(:oli, :genai_routing_primary_only, false)
    assert {:error, :configuration_unavailable} = Router.route(c.ctx, c.config)
  end

  test "explicit local Providers work without an HTTP endpoint or pool", c do
    {:ok, _} = GenAI.update_provider(c.provider, %{adapter: :null, base_url: nil, api_key: nil})
    assert {:ok, %{pool: nil}} = Router.route(c.ctx, c.config)

    assert {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} =
             Execution.generate(c.ctx, messages(), [], c.config)

    assert content == "This is a null provider. No generation performed."
  end

  test "disabled Provider and missing credentials fail closed without backup", c do
    disabled = Repo.update!(Ecto.Changeset.change(c.provider, enabled: false))
    assert {:error, :provider_ineligible} = Router.route(c.ctx, c.config)
    Repo.update!(Ecto.Changeset.change(disabled, enabled: true, api_key: nil))
    assert {:error, :provider_ineligible} = Router.route(c.ctx, c.config)
    refute_receive {:request, _, _}
  end

  test "a primary failure never asks the dynamic router for backup, even after the flag changes",
       c do
    owner = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler_id,
      [:oli, :genai, :router, :decision],
      fn _, _, metadata, _ ->
        send(owner, {:decision, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    task = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config) end)
    assert_receive {:request, server, _}, 2000
    Application.put_env(:oli, :genai_routing_primary_only, false)
    send(server, {:reply, 503, "unavailable"})
    assert {:error, _} = Task.await(task)
    assert_receive {:decision, %{reason: :kill_switch_primary_only}}
    refute_receive {:decision, _}
    refute_receive {:request, _, _}
  end

  test "native capacity remains bounded and cancellation releases a streaming connection", c do
    owner = self()

    task =
      Task.async(fn ->
        Execution.stream(c.ctx, messages(), [], c.config, fn event ->
          send(owner, {:chunk, event})
        end)
      end)

    assert_receive {:request, server, _}, 2000
    send(server, :stream)
    assert_receive {:chunk, _}, 2000
    assert {:ok, plan} = Router.route(c.ctx, c.config)
    assert TransportPool.snapshot(plan.pool).current.capacity == 1

    assert {:error, :busy} =
             TransportPool.connect(plan.pool, c.provider.base_url, checkout_timeout: 20)

    Process.unlink(task.pid)
    Process.exit(task.pid, :kill)
    eventually(fn -> TransportPool.snapshot(plan.pool).current.checked_out == 0 end)
  end

  test "streaming completes and the total deadline still bounds stalled requests", c do
    owner = self()

    task =
      Task.async(fn ->
        Execution.stream(c.ctx, messages(), [], c.config, fn event ->
          send(owner, {:chunk, event})
        end)
      end)

    assert_receive {:request, server, _}, 2000
    send(server, :stream)
    assert_receive {:chunk, _}, 2000
    send(server, :finish)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        Execution.generate(c.ctx, messages(), [], c.config, total_timeout_ms: 150)
      end)

    assert_receive {:request, _, _}, 2000
    assert {:error, :inference_deadline} = Task.await(task)
    {:ok, plan} = Router.route(c.ctx, c.config)
    eventually(fn -> TransportPool.snapshot(plan.pool).current.checked_out == 0 end)
  end

  test "requests for another ServiceConfig preserve existing emergency pools", c do
    {:ok, original} = Router.route(c.ctx, c.config)
    {:ok, other} = GenAI.create_service_config(%{name: "Other", primary_model_id: c.model.id})
    assert {:ok, other_plan} = Router.route(c.ctx, other)
    assert other_plan.pool != original.pool
    assert {:ok, repeated} = Router.route(c.ctx, c.config)
    assert repeated.pool == original.pool
    assert TransportPool.snapshot(original.pool).retired == []
    assert TransportPool.snapshot(other_plan.pool).current != nil
  end

  test "fresh database edits rotate the independent pool and fence old plans", c do
    {:ok, original} = Router.route(c.ctx, c.config)
    {:ok, _} = GenAI.update_provider(c.provider, %{api_key: "rotated-secret"})
    {:ok, current} = Router.route(c.ctx, c.config)
    assert current.pool == original.pool
    assert current.provider.api_key == "rotated-secret"

    assert {:error, :stale_configuration} =
             TransportPool.connect(original.pool, c.provider.base_url,
               expected_signature: original.signature
             )
  end

  defp messages, do: [%Message{role: :user, content: "hello"}]

  defp eventually(fun, remaining \\ 100)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, remaining) do
    case fun.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        eventually(fun, remaining - 1)
    end
  end

  defp accept(listener, owner) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        worker =
          spawn_link(fn ->
            receive do
              :ready -> serve(socket, owner, "")
            end
          end)

        :ok = :gen_tcp.controlling_process(socket, worker)
        send(worker, :ready)
        accept(listener, owner)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket, owner, buffer) do
    # Read the complete JSON body before making the request observable to the test.
    case :binary.split(buffer, "\r\n\r\n") do
      [headers, body] ->
        [_, size] = Regex.run(~r/content-length:\s*(\d+)/i, headers)

        case byte_size(body) >= String.to_integer(size) do
          true ->
            send(owner, {:request, self(), buffer})
            respond(socket)

          false ->
            read_request(socket, owner, buffer)
        end

      _ ->
        read_request(socket, owner, buffer)
    end
  end

  defp read_request(socket, owner, buffer) do
    case :gen_tcp.recv(socket, 0, 3000) do
      {:ok, bytes} -> serve(socket, owner, buffer <> bytes)
      _ -> :gen_tcp.close(socket)
    end
  end

  defp respond(socket) do
    receive do
      {:reply, status, body} ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 #{status} Response\r\ncontent-length: #{byte_size(body)}\r\nconnection: close\r\n\r\n#{body}"
        )

      :stream ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\nconnection: close\r\n\r\ndata: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\n"
        )

        receive do
          :finish ->
            :gen_tcp.send(
              socket,
              "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
            )
        after
          3000 -> :ok
        end
    after
      3000 -> :ok
    end

    :gen_tcp.close(socket)
  end
end
