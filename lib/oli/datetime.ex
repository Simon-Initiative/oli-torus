defmodule Oli.DateTime do
  @callback utc_now :: DateTime.t()

  def utc_now() do
    date_time().utc_now()
  end

  defp date_time(), do: Application.get_env(:oli, :date_time_module, DateTime)
end
