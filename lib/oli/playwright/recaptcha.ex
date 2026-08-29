defmodule Oli.Playwright.Recaptcha do
  @moduledoc """
  Deterministic reCAPTCHA implementation for the isolated Playwright environment.

  The credential-account browser suite exercises Torus registration flows but
  must not depend on the external reCAPTCHA service. `config/ci_e2e.exs`
  selects this module only for that ephemeral environment.
  """

  @behaviour Oli.Recaptcha

  @impl true
  @doc "Returns a successful verification without contacting reCAPTCHA."
  def verify(_response), do: {:success, true}
end
