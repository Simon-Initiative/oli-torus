defmodule Oli.GenAI.Completions.ProviderMessageTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.ProviderMessage

  @secrets [
    "provider-only-key",
    "provider-organization",
    "https://gw.example.com/deployments/provider-only-key"
  ]

  test "the Provider's credentials and endpoint are redacted, then generic key and bearer patterns" do
    message =
      "Key provider-only-key of provider-organization rejected at " <>
        "https://gw.example.com/deployments/provider-only-key/v1/chat/completions; " <>
        "Authorization: Bearer abc.def; see sk-proj-****wxyz"

    assert ProviderMessage.from_body(error_body(message), @secrets) ==
             "Key [redacted] of [redacted] rejected at [redacted]/v1/chat/completions; " <>
               "Authorization: Bearer [redacted]; see [redacted]"
  end

  test "a placeholder credential shorter than 8 characters is not redacted inside other words" do
    assert ProviderMessage.from_body(error_body("Unsupported parameter: 'max_tokens'"), ["x"]) ==
             "Unsupported parameter: 'max_tokens'"
  end

  test "an absent or empty credential redacts nothing" do
    assert ProviderMessage.from_body(error_body("Model gpt-x not found"), ["", nil]) ==
             "Model gpt-x not found"
  end

  test "control characters and whitespace runs collapse, and a long message is cut at 300 characters" do
    assert ProviderMessage.from_body(error_body("Bad\n\trequest \u0007 here  "), []) ==
             "Bad request here"

    assert ProviderMessage.from_body(error_body(String.duplicate("x", 400)), []) ==
             String.duplicate("x", 300) <> "…"
  end

  test "Unicode format characters are removed and ordinary non-ASCII text is kept" do
    assert ProviderMessage.from_body(error_body("Model \u202Egpt-5\u202C not found"), []) ==
             "Model gpt-5 not found"

    assert ProviderMessage.from_body(error_body("\u200B\u2060"), []) == nil

    assert ProviderMessage.from_body(error_body("Modèle «gpt-5» introuvable — 日本語"), []) ==
             "Modèle «gpt-5» introuvable — 日本語"
  end

  test "no message unless the body is an OpenAI-style error with a non-blank string message" do
    for body <- [
          "not json",
          ~s({"error":"plain"}),
          ~s({"error":{"message":42}}),
          ~s({"error":{"message":"  \\n "}}),
          error_body(String.duplicate("x", 70_000)),
          nil
        ] do
      assert ProviderMessage.from_body(body, []) == nil
    end
  end

  defp error_body(message), do: Jason.encode!(%{error: %{message: message}})
end
