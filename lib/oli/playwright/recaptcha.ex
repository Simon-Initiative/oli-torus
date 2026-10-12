defmodule Oli.Playwright.Recaptcha do
  @moduledoc """
  Unconditional local captcha verification for compile-selected Playwright builds.
  Browser tests exercise application workflows without solving Google challenges.
  Production builds retain the normal verifier through `Oli.Recaptcha`.
  """

  @behaviour Oli.Recaptcha

  @impl true
  @doc "Accepts any response, including missing or empty values, without contacting Google."
  @spec verify(term()) :: {:success, true}
  def verify(_response), do: {:success, true}
end
