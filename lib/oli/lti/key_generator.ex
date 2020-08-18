defmodule Oli.Lti do

  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" |> String.split("", trim: true)

  @doc """
  Create a random passphrase of size 256
  """
  def passphrase do
    Enum.map((1..256), fn _i -> Enum.random(@chars) end)
      |> Enum.join("")
  end

  @doc """
  Generates RSA public and private key pair to validate between Tool and the Platform

  ## Examples
    iex> generate_key_pair()
    %{ public_key: "...", private_key: "..." }

  """
  def generate_key_pair do

  end
end
