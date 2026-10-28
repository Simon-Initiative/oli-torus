defmodule Oli.GenAI.Dialogue.ServerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Oli.GenAI.Completions.{Message, ServiceConfig}
  alias Oli.GenAI.Dialogue.{Configuration, Server}

  test "remember prepends generic messages and replaces adaptive runtime updates" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 1, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")]
    }

    {:ok, server} = Server.new(config)

    Server.remember(server, Message.new(:user, "hello"))
    Server.remember(server, Message.new(:system, "runtime 1", "adaptive_runtime_update"))
    Server.remember(server, Message.new(:system, "runtime 2", "adaptive_runtime_update"))

    state = :sys.get_state(server)

    assert Enum.map(state.messages, & &1.content) == ["hello", "base system prompt"]
    assert state.adaptive_runtime_message.content == "runtime 2"

    assert state.adaptive_runtime_message.name == "adaptive_runtime_update"
  end

  @tag capture_log: true
  test "notifies the client when an engagement task crashes" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 1, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")],
      execution_fn: fn _, _, _, _, _, _ -> raise "provider initialization failed" end
    }

    {:ok, server} = Server.new(config)

    Server.engage(server, Message.new(:user, "hello"))

    assert_receive {:dialogue_server, {:error, "An error occurred while processing the request"}},
                   1_000
  end

  test "logs a safe execution failure with service configuration context" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 42, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")],
      execution_fn: fn _, _, _, _, _, _ -> {:error, %{body: "secret response body"}} end
    }

    log =
      capture_log(fn ->
        {:ok, server} = Server.new(config)
        Server.engage(server, Message.new(:user, "hello"))

        assert_receive {:dialogue_server,
                        {:error, "An error occurred while processing the request"}}
      end)

    assert log =~ "event=execution_failed"
    assert log =~ "service_config_id=42"
    refute log =~ "secret response body"
  end

  test "ignores a stale task reply after replacing an engagement" do
    test_pid = self()

    config = %Configuration{
      service_config: %ServiceConfig{id: 1, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: test_pid,
      messages: [Message.new(:system, "base system prompt")],
      execution_fn: fn _, _, _, _, _, _ ->
        send(test_pid, {:execution_started, self()})

        receive do
          :finish -> :ok
        end
      end
    }

    {:ok, server} = Server.new(config)
    on_exit(fn -> if Process.alive?(server), do: GenServer.stop(server) end)

    Server.engage(server, Message.new(:user, "first"))
    assert_receive {:execution_started, _first_task_pid}
    %{engagement_task: %{ref: stale_ref}} = :sys.get_state(server)

    Server.engage(server, Message.new(:user, "second"))
    assert_receive {:execution_started, second_task_pid}

    send(server, {stale_ref, {:noreply, :stale_state}})

    assert %{engagement_task: %{pid: ^second_task_pid}} = :sys.get_state(server)
    assert Process.alive?(server)

    send(second_task_pid, :finish)
  end

  @tag capture_log: true
  test "notifies the client when tool arguments are invalid JSON" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 1, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")]
    }

    {:ok, server} = Server.new(config)

    send(
      server,
      {:stream_chunk, {:function_call, %{"name" => "lookup", "arguments" => "{", "id" => "1"}}}
    )

    send(server, {:stream_chunk, {:function_call_finished}})

    assert_receive {:dialogue_server, {:error, "An error occurred while processing the request"}}
  end

  test "logs invalid tool arguments without exposing their contents" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 7, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")]
    }

    log =
      capture_log(fn ->
        {:ok, server} = Server.new(config)

        send(
          server,
          {:stream_chunk,
           {:function_call,
            %{"name" => "lookup", "arguments" => "secret-invalid-json", "id" => "1"}}}
        )

        send(server, {:stream_chunk, {:function_call_finished}})

        assert_receive {:dialogue_server,
                        {:error, "An error occurred while processing the request"}}
      end)

    assert log =~ "event=tool_arguments_invalid_json"
    refute log =~ "secret-invalid-json"
  end

  @tag capture_log: true
  test "notifies the client when tool execution fails" do
    config = %Configuration{
      service_config: %ServiceConfig{id: 1, primary_model: %{id: 1}},
      functions: [],
      reply_to_pid: self(),
      messages: [Message.new(:system, "base system prompt")]
    }

    {:ok, server} = Server.new(config)

    send(
      server,
      {:stream_chunk, {:function_call, %{"name" => "lookup", "arguments" => "{}", "id" => "1"}}}
    )

    send(server, {:stream_chunk, {:function_call_finished}})

    assert_receive {:dialogue_server, {:error, "An error occurred while processing the request"}}
  end
end
