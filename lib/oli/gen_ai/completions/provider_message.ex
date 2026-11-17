defmodule Oli.GenAI.Completions.ProviderMessage do
  @moduledoc """
  Extracts the `error.message` of a failed OpenAI-style response for administrative diagnostics,
  with the attempt Provider's credentials and endpoint redacted and its length bounded.
  """

  @max_body_bytes 65_536
  @max_length 300
  # Placeholder keys such as "x" or "none" are not secrets, and redacting them would cut words.
  @min_secret_length 8
  @redacted "[redacted]"

  @doc "The largest error body, in bytes, worth reading for a message."
  def max_body_bytes, do: @max_body_bytes

  @doc """
  Returns the sanitized provider message, or nil when the body carries none.

  Unicode format characters are removed first. Every value in `secrets` (credentials, realized
  endpoint URLs) of at least #{@min_secret_length} characters is redacted before the generic key
  and bearer patterns; control characters and whitespace runs become single spaces, and the result
  is capped at #{@max_length} characters.
  """
  def from_body(body, secrets) when is_binary(body) and byte_size(body) <= @max_body_bytes do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} when is_binary(message) ->
        sanitize(message, secrets)

      _ ->
        nil
    end
  end

  def from_body(_, _), do: nil

  defp sanitize(message, secrets) do
    # Invisible format characters go first, so none can split a credential past its redaction.
    visible = String.replace(message, ~r/\p{Cf}/u, "")

    sanitized =
      secrets
      |> Enum.filter(&(is_binary(&1) and String.length(&1) >= @min_secret_length))
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.reduce(visible, &String.replace(&2, &1, @redacted))
      |> String.replace(~r/\bsk-[A-Za-z0-9_\-*]+/u, @redacted)
      |> String.replace(~r/\bBearer\s+[A-Za-z0-9._~+\/=-]+/iu, "Bearer " <> @redacted)
      |> String.replace(~r/[[:cntrl:]]/u, " ")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    case String.length(sanitized) do
      0 -> nil
      length when length > @max_length -> String.slice(sanitized, 0, @max_length) <> "…"
      _ -> sanitized
    end
  end
end
