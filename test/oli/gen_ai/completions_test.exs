defmodule Oli.GenAI.CompletionsTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.RegisteredModel

  test "rejects a non-binary API key for providers that require credentials" do
    model = %RegisteredModel{provider: :open_ai, api_key: :error}

    assert {:error, {:invalid_model_configuration, :missing_api_key}} =
             Completions.validate_registered_model(model)
  end

  test "permits the null provider without an API key" do
    assert :ok = Completions.validate_registered_model(%RegisteredModel{provider: :null})
  end
end
