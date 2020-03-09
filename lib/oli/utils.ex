defmodule Oli.Utils do
  @doc """
  Generates a random hex string of the given length
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16 |> binary_part(0, length)
  end
end
