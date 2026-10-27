defmodule Oli.Recaptcha do
  @moduledoc """
  Compile-selected captcha boundary. Runtime configuration cannot enable the
  Playwright verifier or alter production's Google verification behavior.
  """

  @implementation Application.compile_env(:oli, :recaptcha_module, Oli.Utils.Recaptcha)

  @callback verify(term()) :: {:success, boolean()}

  @doc "Verifies a submitted response using the implementation selected by this build."
  @spec verify(term()) :: {:success, boolean()}
  def verify(response), do: @implementation.verify(response)
end
