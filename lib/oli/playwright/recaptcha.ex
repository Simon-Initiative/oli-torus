defmodule Oli.Playwright.Recaptcha do
  @moduledoc """
  Token verification for compile-selected Playwright builds.
  Only the runner and server receive the runtime secret; it is never included in application responses.
  Production builds retain the normal verifier through `Oli.Recaptcha`.
  """

  @behaviour Oli.Recaptcha

  @impl true
  @doc "Verifies the runtime automation token locally, rejecting absent or invalid credentials."
  @spec verify(term()) :: {:success, boolean()}
  def verify(response) do
    case {response, Application.get_env(:oli, :playwright_captcha_token)} do
      {response, token}
      when is_binary(response) and is_binary(token) and byte_size(token) > 0 ->
        {:success, Plug.Crypto.secure_compare(response, token)}

      _ ->
        {:success, false}
    end
  end
end
