defmodule Oli.GenAI.Dialogue.FallbackTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig, Message}
  alias Oli.GenAI.Dialogue.{Server, Configuration}

  defp wait_for_provider_fallback(server, expected_provider, retries \\ 20) do
    state = :sys.get_state(server)
    if state.registered_model.provider == expected_provider or retries == 0 do
      state
    else
      :timer.sleep(500)
      wait_for_provider_fallback(server, expected_provider, retries - 1)
    end
  end

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

    # Wait for the fallback to process
    state = wait_for_provider_fallback(server, :null)
    
    # Verify that the server state has been updated to now be using the NullProvider
    assert state.registered_model.provider == :null

    Server.engage(server, %Message{role: :user, content: "Hello"})
    # Allow time for the tokens to stream from the NullProvider
    :timer.sleep(3000)

    # We can verify that the server now has an assistant message from the NullProvider
    state = :sys.get_state(server)
    assert Enum.count(state.messages) == 3
    assert Enum.at(state.messages, 2).role == :assistant

    assert Enum.at(state.messages, 2).content ==
             "This is a null provider. No generation performed. "
  end
end
