defmodule Oli.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Oli.Vault

  require Logger

  def after_decrypt(:error) do
    Logger.error("Unable to decrypt an encrypted value; check CLOAK_VAULT_KEY configuration")
    nil
  end

  def after_decrypt(value), do: value
end
