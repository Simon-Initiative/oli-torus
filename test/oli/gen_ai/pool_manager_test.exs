# Acceptance coverage: AC-008, AC-013.
defmodule Oli.GenAI.PoolManagerTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.{PoolManager, Provider, TransportPool}

  setup do
    namespace = make_ref()
    manager = start_supervised!({PoolManager, name: nil, namespace: namespace, poll_ms: 10})
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    server = spawn_link(fn -> accept(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      Process.unlink(server)
      Process.exit(server, :kill)
    end)

    url = "http://127.0.0.1:#{port}"
    {:ok, origin} = Provider.origin(url)

    %{
      manager: manager,
      namespace: namespace,
      url: url,
      spec: %{origin: origin, capacity: 1, signature: 1}
    }
  end

  test "replacement immediately uses a new capacity while old work drains and retires", ctx do
    key = {1, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    {:ok, coordinator} = PoolManager.lookup(ctx.manager, key)
    old = request(ctx, key)
    assert_receive {:connected, old_server}, 2_000
    assert current(ctx, key).checked_out == 1
    old_name = current(ctx, key).name
    :ok = PoolManager.reconcile(ctx.manager, %{key => %{ctx.spec | capacity: 2}})
    assert current(ctx, key).capacity == 2
    refute current(ctx, key).name == old_name

    assert [%{name: ^old_name, checked_out: 1}] =
             PoolManager.snapshot(ctx.manager).pools[key].retired

    fresh = request(ctx, key)
    assert_receive {:connected, fresh_server}, 2_000
    assert current(ctx, key).checked_out == 1
    send(old_server, :finish)
    assert {:ok, "ok"} = Task.await(old, 2_000)
    eventually(fn -> PoolManager.snapshot(ctx.manager).pools[key].retired == [] end)
    assert :undefined = :hackney_pool.find_pool(old_name)
    # A cached logical coordinator refreshes the generation at checkout time.
    assert {:ok, ref} = TransportPool.connect(coordinator, ctx.url)
    :hackney.close(ref)
    assert :undefined = :hackney_pool.find_pool(old_name)
    send(fresh_server, :finish)
    assert {:ok, "ok"} = Task.await(fresh, 2_000)
  end

  test "separate ServiceConfigs, backup and probes remain isolated under saturation", ctx do
    keys = [{1, :primary}, {2, :primary}, {1, :backup}, {:probe, 1}]
    :ok = PoolManager.reconcile(ctx.manager, Map.new(keys, &{&1, ctx.spec}))
    saturated = request(ctx, {1, :primary})
    assert_receive {:connected, server}, 2_000

    assert {:error, :busy} =
             PoolManager.connect(ctx.manager, {1, :primary}, ctx.url, checkout_timeout: 30)

    for key <- tl(keys) do
      assert {:ok, ref} = PoolManager.connect(ctx.manager, key, ctx.url)
      :hackney.close(ref)
    end

    send(server, :finish)
    assert {:ok, "ok"} = Task.await(saturated, 2_000)
  end

  test "retiring a removed key rejects stale coordinators and drains the native pool", ctx do
    key = {3, :secondary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    {:ok, coordinator} = PoolManager.lookup(ctx.manager, key)
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000
    name = current(ctx, key).name
    :ok = PoolManager.reconcile(ctx.manager, %{})
    assert {:error, :pool_unavailable} = PoolManager.lookup(ctx.manager, key)
    assert {:error, :pool_unavailable} = TransportPool.connect(coordinator, ctx.url)
    assert PoolManager.snapshot(ctx.manager).retiring[key].retired != []
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
    eventually(fn -> PoolManager.snapshot(ctx.manager).retiring == %{} end)
    assert :undefined = :hackney_pool.find_pool(name)
  end

  test "a coordinator restart adopts old checkouts without losing their accounting", ctx do
    key = {4, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    {:ok, coordinator} = PoolManager.lookup(ctx.manager, key)
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000
    old_name = current(ctx, key).name
    Process.exit(coordinator, :kill)
    eventually(fn -> PoolManager.lookup(ctx.manager, key) == {:error, :pool_unavailable} end)
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})

    assert [%{name: ^old_name, checked_out: 1}] =
             PoolManager.snapshot(ctx.manager).pools[key].retired

    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
    eventually(fn -> PoolManager.snapshot(ctx.manager).pools[key].retired == [] end)
  end

  test "one origin is enforced and endpoint changes replace rather than reuse", ctx do
    key = {5, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})

    assert {:error, :invalid_origin} =
             PoolManager.connect(ctx.manager, key, "http://elsewhere.invalid")

    name = current(ctx, key).name
    changed = %{ctx.spec | origin: {"http", "localhost", URI.parse(ctx.url).port}, signature: 2}
    :ok = PoolManager.reconcile(ctx.manager, %{key => changed})
    refute name == current(ctx, key).name
    assert {:error, :invalid_origin} = PoolManager.connect(ctx.manager, key, ctx.url)
  end

  test "re-adding a retiring key reuses its coordinator without losing old generations", ctx do
    key = {6, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    {:ok, coordinator} = PoolManager.lookup(ctx.manager, key)
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000
    old_name = current(ctx, key).name
    :ok = PoolManager.reconcile(ctx.manager, %{})
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    assert {:ok, ^coordinator} = PoolManager.lookup(ctx.manager, key)
    assert [%{name: ^old_name}] = PoolManager.snapshot(ctx.manager).pools[key].retired
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
    eventually(fn -> PoolManager.snapshot(ctx.manager).pools[key].retired == [] end)
  end

  test "a short checkout budget is not queued behind another slow checkout", ctx do
    key = {7, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000

    long =
      Task.async(fn ->
        PoolManager.connect(ctx.manager, key, ctx.url, checkout_timeout: 500, connect_timeout: 20)
      end)

    eventually(fn -> current(ctx, key).queue_depth == 1 end)
    started = System.monotonic_time(:millisecond)

    assert {:error, :busy} =
             PoolManager.connect(ctx.manager, key, ctx.url,
               checkout_timeout: 10,
               connect_timeout: 20
             )

    assert System.monotonic_time(:millisecond) - started < 250
    assert {:error, :busy} = Task.await(long, 2_000)
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
  end

  test "replacement and probe lookup remain responsive during production checkout contention",
       ctx do
    key = {8, :primary}
    probe = {:probe, 8}
    specs = %{key => ctx.spec, probe => ctx.spec}
    :ok = PoolManager.reconcile(ctx.manager, specs)
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000

    waiting =
      Task.async(fn ->
        PoolManager.connect(ctx.manager, key, ctx.url, checkout_timeout: 500, connect_timeout: 20)
      end)

    eventually(fn -> current(ctx, key).queue_depth == 1 end)
    started = System.monotonic_time(:millisecond)
    assert :ok = PoolManager.reconcile(ctx.manager, %{specs | key => %{ctx.spec | capacity: 2}})

    assert {:ok, ref} =
             PoolManager.connect(ctx.manager, probe, ctx.url,
               checkout_timeout: 50,
               connect_timeout: 50
             )

    assert System.monotonic_time(:millisecond) - started < 250
    :hackney.close(ref)
    assert {:error, :busy} = Task.await(waiting, 2_000)
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
    eventually(fn -> PoolManager.snapshot(ctx.manager).pools[key].retired == [] end)
  end

  test "killing a caller removes its pending connection startup and native waiter", ctx do
    key = {9, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000

    waiting =
      Task.async(fn ->
        PoolManager.connect(ctx.manager, key, ctx.url, checkout_timeout: 1_000)
      end)

    eventually(fn -> current(ctx, key).queue_depth == 1 end)
    Process.unlink(waiting.pid)
    Process.exit(waiting.pid, :kill)
    eventually(fn -> current(ctx, key).queue_depth == 0 end)
    assert current(ctx, key).checked_out == 1
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
  end

  test "coordinator death closes an unclaimed transferred connection in a living caller", ctx do
    key = {10, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    {:ok, coordinator} = PoolManager.lookup(ctx.manager, key)
    name = current(ctx, key).name
    parent = self()

    caller =
      Task.async(fn ->
        token = make_ref()
        deadline = System.monotonic_time(:millisecond) + 2_000

        assert {:handoff, _ref, _worker} =
                 GenServer.call(coordinator, {:connect, token, ctx.url, [], deadline}, :infinity)

        send(parent, :unclaimed_connection)

        receive do
          :finish -> :ok
        end
      end)

    assert_receive :unclaimed_connection, 2_000
    assert :hackney_pool.get_stats(name)[:in_use_count] == 1
    Process.exit(coordinator, :kill)
    eventually(fn -> :hackney_pool.get_stats(name)[:in_use_count] == 0 end)
    assert Process.alive?(caller.pid)
    send(caller.pid, :finish)
    assert :ok = Task.await(caller, 2_000)
    eventually(fn -> PoolManager.lookup(ctx.manager, key) == {:error, :pool_unavailable} end)
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
  end

  test "manager restart retires orphan generations even when their logical key was deleted",
       ctx do
    key = {11, :primary}
    :ok = PoolManager.reconcile(ctx.manager, %{key => ctx.spec})
    active = request(ctx, key)
    assert_receive {:connected, server}, 2_000
    name = current(ctx, key).name
    assert :ok = stop_supervised(PoolManager)
    manager = start_supervised!({PoolManager, name: nil, namespace: ctx.namespace, poll_ms: 10})
    :ok = PoolManager.reconcile(manager, %{})
    assert [%{name: ^name, checked_out: 1}] = PoolManager.snapshot(manager).retiring[key].retired
    send(server, :finish)
    assert {:ok, "ok"} = Task.await(active, 2_000)
    eventually(fn -> PoolManager.snapshot(manager).retiring == %{} end)
    assert :undefined = :hackney_pool.find_pool(name)
  end

  defp current(ctx, key), do: PoolManager.snapshot(ctx.manager).pools[key].current

  defp request(ctx, key) do
    Task.async(fn ->
      with {:ok, ref} <- PoolManager.connect(ctx.manager, key, ctx.url) do
        try do
          with {:ok, 200, _, response} <- :hackney.send_request(ref, {:get, "/", [], <<>>}),
               {:ok, body} <- :hackney.body(response),
               do: {:ok, body}
        after
          :hackney.close(ref)
        end
      end
    end)
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
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, _} ->
        :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: close\r\n\r\n")
        send(parent, {:connected, self()})

        receive do
          :finish -> :gen_tcp.send(socket, "ok")
        after
          5_000 -> :ok
        end

      {:error, _} ->
        :ok
    end

    :gen_tcp.close(socket)
  end
end
