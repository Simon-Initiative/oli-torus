defmodule Oli.Vault do
  use Cloak.Vault, otp_app: :oli

  require Logger

  @impl GenServer
  def init(config) do
    Logger.info("Initializing Oli.Vault")

    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: get_vault_key!()}
      )

    {:ok, config}
  end

  defp get_vault_key!() do
    case System.get_env("CLOAK_VAULT_KEY") do
      nil ->
        if Mix.env() in [:dev, :test] do
          # For dev and tests, we can use a default key
          Base.decode64!("HXCdm5z61eNgUpnXObJRv94k3JnKSrnfwppyb60nz6w=")
        else
          raise "Environment variable CLOAK_VAULT_KEY not set"
        end

      value ->
        Base.decode64!(value)
    end
  end
end
