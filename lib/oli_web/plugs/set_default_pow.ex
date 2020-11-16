defmodule Oli.Plugs.SetDefaultPow do

  def init(name), do: name

  def call(conn, name) do
    OliWeb.Pow.PowHelpers.use_pow_config(conn, name)
  end

end
