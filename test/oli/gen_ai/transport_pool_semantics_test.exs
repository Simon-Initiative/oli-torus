# Acceptance coverage: AC-011, AC-014, AC-015, AC-016.
defmodule Oli.GenAI.TransportPoolSemanticsTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.Completions.{OpenAICompliantProvider, RegisteredModel}
  alias Oli.GenAI.HackneyPool

  @pool :genai_transport_semantics_test

  setup do
    :ok = :hackney_pool.start_pool(@pool, max_connections: 2, timeout: 5_000)

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_address, port}} = :inet.sockname(listener)
    parent = self()
    server = spawn_link(fn -> accept_connections(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      Process.unlink(server)
      Process.exit(server, :kill)
      :hackney_pool.stop_pool(@pool)
    end)

    %{url: "http://127.0.0.1:#{port}/"}
  end

  test "streaming retains a checkout, queues at capacity and removes timed out waiters", %{
    url: url
  } do
    :hackney_pool.set_max_connections(@pool, 1)
    assert :hackney_pool.max_connections(@pool) == 1
    first = start_stream(url)
    assert_receive {:connected, handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 end)

    waiter = Task.async(fn -> :hackney.get(url, [], <<>>, pool: @pool, checkout_timeout: 200) end)
    assert_eventually(fn -> stat(:queue_count) == 1 end)
    assert {:error, :checkout_timeout} = Task.await(waiter, 2_000)
    assert_eventually(fn -> stat(:queue_count) == 0 end)
    assert stat(:in_use_count) == 1

    send(handler, :finish)
    assert {:ok, _} = Task.await(first, 2_000)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
  end

  test "killing a stream and a pending checkout reclaims pool capacity", %{url: url} do
    :hackney_pool.set_max_connections(@pool, 1)
    assert :hackney_pool.max_connections(@pool) == 1
    first = start_stream(url)
    assert_receive {:connected, _handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 end)

    waiter =
      Task.async(fn -> :hackney.get(url, [], <<>>, pool: @pool, checkout_timeout: 5_000) end)

    assert_eventually(fn -> stat(:queue_count) == 1 end)
    Process.unlink(waiter.pid)
    Process.exit(waiter.pid, :kill)
    assert_eventually(fn -> stat(:queue_count) == 0 end)
    Process.unlink(first.pid)
    Process.exit(first.pid, :kill)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
  end

  test "HTTPoison async streaming holds checkout and killed owner releases it", %{url: url} do
    parent = self()

    task =
      Task.async(fn ->
        {:ok, response} =
          HTTPoison.get(url, [], stream_to: self(), async: :once, hackney: [pool: @pool])

        receive do
          %HTTPoison.AsyncStatus{id: id} when id == response.id ->
            HTTPoison.stream_next(response)
        end

        receive do
          %HTTPoison.AsyncHeaders{id: id} when id == response.id ->
            send(parent, :async_headers_received)

            receive do
              :finish -> :ok
            end
        end
      end)

    assert_receive {:connected, _handler}, 2_000
    assert_receive :async_headers_received, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 end)
    Process.unlink(task.pid)
    Process.exit(task.pid, :kill)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
  end

  test "lowering capacity does not prevent queued checkout during drain", %{url: url} do
    first = start_stream(url)
    second = start_stream(url)
    assert_receive {:connected, handler1}, 2_000
    assert_receive {:connected, _handler2}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 2 end)
    waiter = start_stream(url)
    assert_eventually(fn -> stat(:queue_count) == 1 end)
    :hackney_pool.set_max_connections(@pool, 1)
    assert :hackney_pool.max_connections(@pool) == 1
    send(handler1, :finish)
    assert_receive {:connected, _handler3}, 2_000
    assert_eventually(fn -> stat(:queue_count) == 0 and stat(:in_use_count) == 2 end)

    for task <- [first, second, waiter] do
      Process.unlink(task.pid)
      Process.exit(task.pid, :kill)
    end
  end

  test "a replacement pool accepts work while the old pool drains", %{url: url} do
    replacement = :genai_transport_replacement_test
    :ok = :hackney_pool.start_pool(replacement, max_connections: 1, timeout: 5_000)
    on_exit(fn -> :hackney_pool.stop_pool(replacement) end)

    old_request = start_stream(url)
    assert_receive {:connected, old_handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 end)

    new_request =
      Task.async(fn ->
        with {:ok, 200, _, ref} <-
               :hackney.get(url, [], <<>>, pool: replacement, checkout_timeout: 1_000),
             {:ok, body} <- :hackney.body(ref) do
          {:ok, body}
        end
      end)

    assert_receive {:connected, new_handler}, 2_000

    assert_eventually(fn ->
      :hackney_pool.get_stats(replacement)[:in_use_count] == 1 and stat(:in_use_count) == 1
    end)

    assert {:error, :checkout_timeout} =
             :hackney.get(url, [], <<>>, pool: replacement, checkout_timeout: 50)

    assert_eventually(fn -> :hackney_pool.get_stats(replacement)[:queue_count] == 0 end)

    send(old_handler, :finish)
    assert {:ok, "ok"} = Task.await(old_request, 2_000)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
    assert :ok = :hackney_pool.stop_pool(@pool)
    assert :undefined = :hackney_pool.find_pool(@pool)
    assert :hackney_pool.get_stats(replacement)[:in_use_count] == 1
    send(new_handler, :finish)
    assert {:ok, "ok"} = Task.await(new_request, 2_000)
    assert_eventually(fn -> :hackney_pool.get_stats(replacement)[:in_use_count] == 0 end)
  end

  test "idle connections are distinct from checked-out occupancy and are reused", %{url: url} do
    :hackney_pool.set_max_connections(@pool, 1)
    assert :hackney_pool.max_connections(@pool) == 1
    first = start_stream(url <> "keepalive")
    assert_receive {:connected, handler}, 2_000
    send(handler, :finish)
    assert {:ok, "ok"} = Task.await(first, 2_000)
    assert_eventually(fn -> stat(:in_use_count) == 0 and stat(:free_count) == 1 end)
    assert :hackney_pool.count(@pool) == 1

    second = start_stream(url <> "keepalive")
    assert_receive {:connected, ^handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 and stat(:free_count) == 0 end)

    assert {:error, :checkout_timeout} =
             :hackney.get(url, [], <<>>, pool: @pool, checkout_timeout: 50)

    send(handler, :finish)
    assert {:ok, "ok"} = Task.await(second, 2_000)
    assert_eventually(fn -> stat(:in_use_count) == 0 and stat(:free_count) == 1 end)
  end

  test "a reused idle connection can exceed the limit when a pool spans origins", %{url: url} do
    :hackney_pool.set_max_connections(@pool, 1)
    assert :hackney_pool.max_connections(@pool) == 1
    warmup = start_stream(url <> "keepalive")
    assert_receive {:connected, handler}, 2_000
    send(handler, :finish)
    assert {:ok, "ok"} = Task.await(warmup, 2_000)
    assert_eventually(fn -> stat(:free_count) == 1 end)

    other_origin = start_stream(String.replace(url, "127.0.0.1", "localhost"))
    assert_receive {:connected, other_handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 1 and stat(:free_count) == 1 end)
    reused = start_stream(url <> "keepalive")
    assert_receive {:connected, ^handler}, 2_000
    assert_eventually(fn -> stat(:in_use_count) == 2 end)
    send(other_handler, :finish)
    send(handler, :finish)
    assert {:ok, "ok"} = Task.await(other_origin, 2_000)
    assert {:ok, "ok"} = Task.await(reused, 2_000)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
  end

  test "OpenAI adapter keeps checkout through SSE consumption and releases on completion", %{
    url: url
  } do
    pool = HackneyPool.pool_name(:slow)
    baseline = pool_stat(pool, :in_use_count)
    parent = self()

    task =
      Task.async(fn ->
        OpenAICompliantProvider.stream([], [], model(url), fn event ->
          send(parent, {:adapter, event})
        end)
      end)

    assert_receive {:connected, handler}, 2_000
    assert_receive {:adapter, {:tokens_received, "hello"}}, 2_000
    assert_eventually(fn -> pool_stat(pool, :in_use_count) == baseline + 1 end)
    send(handler, :finish)
    assert_receive {:adapter, {:tokens_finished}}, 2_000
    assert :ok = Task.await(task, 2_000)
    assert_eventually(fn -> pool_stat(pool, :in_use_count) == baseline end)
  end

  test "OpenAI adapter killed during SSE consumption releases checkout", %{url: url} do
    pool = HackneyPool.pool_name(:slow)
    baseline = pool_stat(pool, :in_use_count)
    parent = self()

    task =
      Task.async(fn ->
        OpenAICompliantProvider.stream([], [], model(url), fn event ->
          send(parent, {:adapter, event})
        end)
      end)

    assert_receive {:connected, _handler}, 2_000
    assert_receive {:adapter, {:tokens_received, "hello"}}, 2_000
    assert_eventually(fn -> pool_stat(pool, :in_use_count) == baseline + 1 end)
    Process.unlink(task.pid)
    monitor = Process.monitor(task.pid)
    Process.exit(task.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 2_000
    assert_eventually(fn -> pool_stat(pool, :in_use_count) == baseline end)
  end

  test "OpenAI adapter closes checkout when its consumer cancels with an exception", %{url: url} do
    pool = HackneyPool.pool_name(:slow)
    baseline = pool_stat(pool, :in_use_count)

    parent = self()

    task =
      Task.async(fn ->
        try do
          OpenAICompliantProvider.stream([], [], model(url), fn _ -> throw(:cancelled) end)
        catch
          :cancelled -> send(parent, :consumer_cancelled)
        end

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:connected, _handler}, 2_000
    assert_receive :consumer_cancelled, 2_000
    assert_eventually(fn -> pool_stat(pool, :in_use_count) == baseline end)
    send(task.pid, :finish)
    assert :ok = Task.await(task, 2_000)
  end

  test "stopping async delivery retains checkout until explicitly closed", %{url: url} do
    {:ok, response} =
      HTTPoison.get(url, [], stream_to: self(), async: :once, hackney: [pool: @pool])

    assert_receive {:connected, _handler}, 2_000
    assert_receive %HTTPoison.AsyncStatus{id: id}, 2_000
    assert id == response.id
    assert_eventually(fn -> stat(:in_use_count) == 1 end)
    assert {:ok, ^id} = :hackney.stop_async(id)
    assert stat(:in_use_count) == 1
    :hackney.close(id)
    assert_eventually(fn -> stat(:in_use_count) == 0 end)
  end

  defp model(url) do
    %RegisteredModel{
      model: "test-model",
      api_key: "local-test-key",
      url_template: String.trim_trailing(url, "/"),
      timeout: 1_000,
      recv_timeout: 2_000,
      pool_class: :slow
    }
  end

  defp pool_stat(pool, key), do: pool |> :hackney_pool.get_stats() |> Keyword.fetch!(key)

  defp start_stream(url) do
    Task.async(fn ->
      with {:ok, 200, _, ref} <- :hackney.get(url, [], <<>>, pool: @pool, checkout_timeout: 5_000),
           {:ok, body} <- :hackney.body(ref) do
        {:ok, body}
      end
    end)
  end

  defp stat(key), do: @pool |> :hackney_pool.get_stats() |> Keyword.fetch!(key)

  defp assert_eventually(fun, attempts \\ 100)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    unless fun.() do
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp accept_connections(listener, parent) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        handler = spawn_link(fn -> serve(socket, parent) end)
        :ok = :gen_tcp.controlling_process(socket, handler)
        send(handler, :ready)
        accept_connections(listener, parent)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket, parent) do
    receive do
      :ready -> :ok
    end

    serve_request(socket, parent)
  end

  defp serve_request(socket, parent) do
    request = recv_headers(socket, "")
    keepalive? = String.starts_with?(request, "GET /keepalive ")
    sse? = String.starts_with?(request, "POST /v1/chat/completions ")

    case sse? do
      true ->
        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n"
          )

        send_chunk(socket, "data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\n")

      false ->
        connection =
          case keepalive? do
            true -> "keep-alive"
            false -> "close"
          end

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-length: 2\r\nconnection: #{connection}\r\n\r\n"
          )
    end

    send(parent, {:connected, self()})

    receive do
      :finish ->
        case sse? do
          true ->
            send_chunk(
              socket,
              "data: {\"choices\":[{\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
            )

            :gen_tcp.send(socket, "0\r\n\r\n")

          false ->
            :gen_tcp.send(socket, "ok")
        end
    after
      10_000 -> :ok
    end

    case keepalive? do
      true -> serve_request(socket, parent)
      false -> :gen_tcp.close(socket)
    end
  end

  defp recv_headers(socket, buffer) do
    case String.contains?(buffer, "\r\n\r\n") do
      true ->
        buffer

      false ->
        {:ok, data} = :gen_tcp.recv(socket, 0, 2_000)
        recv_headers(socket, buffer <> data)
    end
  end

  defp send_chunk(socket, data) do
    :gen_tcp.send(socket, [Integer.to_string(byte_size(data), 16), "\r\n", data, "\r\n"])
  end
end
