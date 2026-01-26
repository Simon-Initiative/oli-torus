defmodule Oli.GenAI.Dialogue.FallbackTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig, Message}
  alias Oli.GenAI.Dialogue.{Server, Configuration}

  test "falls back to NullProvider when primary provider fails" do
    # Configure a bogus primary model that simulates a failure
    primary = %RegisteredModel{
      provider: :open_ai,
      model: "foo",
      url_template: "https://api.thisserverdoesnotexist.com"
    }

    backup = %RegisteredModel{
      provider: :null,
      model: "bar",
      url_template: "https://api.null.com/v1/chat/completions"
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

    Server.engage(server, %Message{role: :user, content: "Hello"})

    state = wait_for_assistant_message(server)
    assert Enum.count(state.messages) == 3
    assert Enum.at(state.messages, 2).role == :assistant

    content = Enum.at(state.messages, 2).content
    assert String.contains?(content, "null")
    assert String.contains?(content, "performed")
  end

  defp wait_for_assistant_message(server, retries \\ 30) do
    state = :sys.get_state(server)
    assistant = Enum.at(state.messages, 2)
    complete? =
      is_map(assistant) and assistant.role == :assistant and
        String.contains?(assistant.content, "No generation performed.")

    if complete? or retries == 0 do
      state
    else
      :timer.sleep(300)
      wait_for_assistant_message(server, retries - 1)
    end
  end
end
