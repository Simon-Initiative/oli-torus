defmodule Oli.GenAI.ProviderTest do
  # Not async: other GenAI tests change :genai_max_completion_tokens_hosts.
  use ExUnit.Case, async: false

  alias Oli.GenAI.Provider
  alias Oli.GenAI.Completions.RegisteredModel

  @model %RegisteredModel{model: "gpt-5"}

  describe "token_limit_parameter/2" do
    test "OpenAI's own API host selects max_completion_tokens, whatever the case, port or path" do
      for url <- ["https://api.openai.com", "HTTPS://API.OpenAI.COM:443/v1?api-version=1"] do
        assert Provider.token_limit_parameter(provider(url), @model) == :max_completion_tokens
      end
    end

    test "every other or unreadable endpoint keeps max_tokens" do
      for url <- [
            "http://localhost:11434",
            "https://gateway.example.com/openai",
            "https://api.openai.com.gateway.example.com",
            "not a url",
            nil
          ] do
        assert Provider.token_limit_parameter(provider(url), @model) == :max_tokens
      end
    end
  end

  defp provider(url), do: %Provider{base_url: url, api_key: "key", organization_key: nil}
end
