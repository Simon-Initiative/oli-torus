defmodule Oli.GenAI.Dialogue.FallbackTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig, Message}
  alias Oli.GenAI.Dialogue.{Server, Configuration}

  test "returns an error when primary provider fails" do
    # Configure a bogus primary model that simulates a failure
    primary = %RegisteredModel{
      model: "foo"
    }

    backup = %RegisteredModel{
      model: "bar"
    }

    service_config = %ServiceConfig{primary_model: primary, backup_model: backup}

    config = %Configuration{
      service_config: service_config,
      functions: [],
      reply_to_pid: self(),
      messages: []
    }

    # Start the server and send a user message
    {:ok, server} = Server.new(config)
    Server.engage(server, %Message{role: :user, content: "Hello"})

    assert_receive {:dialogue_server, {:error, "An error occurred while processing the request"}},
                   5_000
  end
end
