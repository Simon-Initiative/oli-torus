defmodule Oli.DateTime do
  @callback utc_now :: DateTime.t()
  @callback now!(String.t()) :: DateTime.t()

  def utc_now() do
    date_time().utc_now()
  end

  def now!(timezone) do
    date_time().now!(timezone)
  end

  defp date_time(), do: Application.get_env(:oli, :date_time_module, DateTime)
end
