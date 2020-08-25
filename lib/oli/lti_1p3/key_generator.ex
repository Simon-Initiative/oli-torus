defmodule Oli.Lti_1p3.KeyGenerator do

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
    %{ public_key: "...", private_key: "...", key_id: "..." }

  """
  def generate_key_pair do
    key_id = passphrase()

    # TODO: Look into private key encryption using key_id?
    # {:ok, aes_256_key} = ExCrypto.generate_aes_key(:aes_256, :bytes)

    {:ok, rsa_priv_key} = ExPublicKey.generate_key(4096)
    {:ok, public_key} = ExPublicKey.public_key_from_private_key(rsa_priv_key)

    {:ok, private_key_pem} = ExPublicKey.pem_encode(rsa_priv_key)
    {:ok, public_key_pem} = ExPublicKey.pem_encode(public_key)

    # {:ok, {_iv, encrypted_private_key_pem}} = ExCrypto.encrypt(aes_256_key, private_key_pem)
    # {:ok, encrypted_private_key_pem} = ExPublicKey.pem_encode(encrypted_private_key)

    %{public_key: public_key_pem, private_key: private_key_pem, key_id: key_id}
  end
end
