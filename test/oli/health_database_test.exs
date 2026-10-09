defmodule Oli.HealthDatabaseTest do
  use ExUnit.Case, async: false

  alias Oli.Health
  alias Oli.Repo

  setup do
    # A real one-connection pool tests checkout without changing the application pool.
    repo =
      start_supervised!(
        {Repo,
         name: nil,
         pool: DBConnection.ConnectionPool,
         pool_size: 1,
         queue_target: 5_000,
         queue_interval: 5_000}
      )

    previous = Repo.put_dynamic_repo(repo)
    assert {:ok, _} = Repo.query("SELECT 1", [], log: false)
    Health.starting()
    Health.started()

    on_exit(fn ->
      Repo.put_dynamic_repo(previous)
      Health.starting()
      Health.started()
    end)

    {:ok, repo: repo}
  end

  test "required local services fail closed and recover independently of liveness" do
    assert Health.ready?()

    for name <- [Oli.Repo, Oli.PubSub, Oli.Vault] do
      pid = Process.whereis(name)
      Process.unregister(name)

      try do
        refute Health.ready?()
        assert Health.live?()
      after
        Process.register(pid, name)
      end

      assert Health.ready?()
    end
  end

  test "NodeJS is excluded even when the configured evaluator uses it" do
    previous = Application.fetch_env!(:oli, :rule_evaluator)

    Application.put_env(:oli, :rule_evaluator,
      dispatcher: Oli.Delivery.Attempts.ActivityLifecycle.NodeEvaluator
    )

    try do
      for name <- [NodeJS.Supervisor, NodeJS.Supervisor.Pool] do
        case Process.whereis(name) do
          nil ->
            assert Health.ready?()

          pid ->
            Process.unregister(name)

            try do
              assert Health.ready?()
              assert Health.live?()
            after
              Process.register(pid, name)
            end
        end
      end
    after
      Application.put_env(:oli, :rule_evaluator, previous)
    end
  end

  test "exhausted pool has one total budget and expired probes leave no live tasks", %{repo: repo} do
    parent = self()

    holder =
      Task.async(fn ->
        Repo.put_dynamic_repo(repo)

        Repo.checkout(
          fn ->
            send(parent, :checked_out)

            receive do
              :release -> :ok
            end
          end,
          timeout: 10_000
        )
      end)

    assert_receive :checked_out

    try do
      for _ <- 1..3 do
        {:links, before_links} = Process.info(self(), :links)
        start = System.monotonic_time(:millisecond)
        refute Health.ready?()
        elapsed = System.monotonic_time(:millisecond) - start
        assert elapsed >= 900
        assert elapsed < 1_300
        assert Health.live?()
        {:links, after_links} = Process.info(self(), :links)
        assert MapSet.new(after_links) == MapSet.new(before_links)
      end
    after
      send(holder.pid, :release)
      Task.await(holder)
    end

    assert Health.ready?()
  end

  test "repository exit is private and recovery needs no lifecycle reset", %{repo: repo} do
    missing = spawn(fn -> :ok end)
    monitor = Process.monitor(missing)
    assert_receive {:DOWN, ^monitor, :process, ^missing, _}
    Repo.put_dynamic_repo(missing)
    refute Health.ready?()
    assert Health.live?()
    Repo.put_dynamic_repo(repo)
    assert Health.ready?()
  end

  test "stalled PostgreSQL responses and socket disconnections are bounded and recover" do
    config = Repo.config()
    gate = :atomics.new(1, signed: false)
    supervisor = start_supervised!({Task.Supervisor, []})
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    upstream = {String.to_charlist(config[:hostname] || "localhost"), config[:port] || 5432}

    {:ok, _} =
      Task.Supervisor.start_child(supervisor, fn ->
        accept_connections(listener, upstream, supervisor, gate, parent)
      end)

    proxy_config =
      Keyword.merge(config,
        url: nil,
        hostname: "127.0.0.1",
        port: port,
        name: nil,
        pool: DBConnection.ConnectionPool,
        pool_size: 1,
        idle_interval: 60_000,
        backoff_min: 10,
        backoff_max: 10
      )

    repo = start_supervised!(Supervisor.child_spec({Repo, proxy_config}, id: :proxy_repo))
    previous = Repo.put_dynamic_repo(repo)

    try do
      assert Health.ready?()

      for mode <- [1, 2] do
        :atomics.put(gate, 1, mode)
        start = System.monotonic_time(:millisecond)
        refute Health.ready?()
        assert System.monotonic_time(:millisecond) - start < 1_300
        assert_receive {:interrupted_response, ^mode}
        assert Health.live?()
        :atomics.put(gate, 1, 0)
        # The same normal pool reconnects; no lifecycle reset is needed.
        assert Health.ready?()
      end
    after
      Repo.put_dynamic_repo(previous)
      stop_supervised(:proxy_repo)
      :gen_tcp.close(listener)
      stop_supervised(Task.Supervisor)
    end
  end

  test "drain during the query is rechecked before returning ready" do
    handler = "health-drain-#{System.unique_integer()}"
    :telemetry.attach(handler, [:oli, :repo, :query], &__MODULE__.drain_on_query/4, self())

    try do
      refute Health.ready?()
      assert_receive :queried
      assert Health.live?()
      assert Health.state() == :draining
    after
      :telemetry.detach(handler)
    end
  end

  test "slow query completion is canceled within the same budget" do
    handler = "health-slow-#{System.unique_integer()}"
    :telemetry.attach(handler, [:oli, :repo, :query], &__MODULE__.block_on_query/4, self())

    try do
      start = System.monotonic_time(:millisecond)
      refute Health.ready?()
      assert System.monotonic_time(:millisecond) - start < 1_300
      assert_receive {:query_worker, worker}
      refute Process.alive?(worker)
    after
      :telemetry.detach(handler)
    end

    assert Health.ready?()
  end

  def drain_on_query(_event, _measurements, %{query: "SELECT 1"}, parent) do
    Health.drain()
    send(parent, :queried)
  end

  def drain_on_query(_, _, _, _), do: :ok

  def block_on_query(_event, _measurements, %{query: "SELECT 1"}, parent) do
    send(parent, {:query_worker, self()})

    receive do
      :finish -> :ok
    end
  end

  def block_on_query(_, _, _, _), do: :ok

  # A loopback TCP relay stalls or closes actual database responses without
  # changing PostgreSQL, the application pool, or production query code.
  defp accept_connections(listener, upstream, supervisor, gate, observer) do
    case :gen_tcp.accept(listener) do
      {:ok, client} ->
        {:ok, relay} =
          Task.Supervisor.start_child(supervisor, fn ->
            receive do
              {:client, socket} -> proxy_connection(socket, upstream, gate, observer)
            end
          end)

        :ok = :gen_tcp.controlling_process(client, relay)
        send(relay, {:client, client})
        accept_connections(listener, upstream, supervisor, gate, observer)

      {:error, :closed} ->
        :ok
    end
  end

  defp proxy_connection(client, {host, port}, gate, observer) do
    {:ok, server} = :gen_tcp.connect(host, port, [:binary, active: true], 2_000)
    :ok = :inet.setopts(client, active: true)

    try do
      relay_packets(client, server, gate, observer)
    after
      :gen_tcp.close(client)
      :gen_tcp.close(server)
    end
  end

  defp relay_packets(client, server, gate, observer) do
    receive do
      {:tcp, ^client, data} ->
        case :gen_tcp.send(server, data) do
          :ok -> relay_packets(client, server, gate, observer)
          {:error, _} -> :ok
        end

      {:tcp, ^server, data} ->
        case :atomics.get(gate, 1) do
          0 ->
            case :gen_tcp.send(client, data) do
              :ok -> relay_packets(client, server, gate, observer)
              {:error, _} -> :ok
            end

          1 ->
            send(observer, {:interrupted_response, 1})
            relay_packets(client, server, gate, observer)

          2 ->
            send(observer, {:interrupted_response, 2})
        end

      {:tcp_closed, _} ->
        :ok

      {:tcp_error, _, _} ->
        :ok
    end
  end
end
