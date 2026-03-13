defmodule Oli.GenAI.Dialogue.ServerTest do
  use ExUnit.Case, async: true

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

    assert Enum.map(state.messages, & &1.content) == ["runtime 2", "hello", "base system prompt"]

    assert Enum.count(state.messages, &(&1.name == "adaptive_runtime_update")) == 1
  end
end
