defmodule Oli.Recaptcha do
  @callback verify(String.t()) :: {:success, boolean()}

  def verify(response_string) do
    impl().verify(response_string)
  end

  defp impl(), do: Application.get_env(:oli, :recaptcha_module, Oli.Utils.Recaptcha)
end
