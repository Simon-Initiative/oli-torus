defmodule Oli.Date do
  @callback utc_today :: Date.t()

  def utc_today() do
    date().utc_today()
  end

  defp date(), do: Application.get_env(:oli, :date_module, Date)
end
