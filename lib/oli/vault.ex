defmodule Oli.Vault do
  use Cloak.Vault, otp_app: :oli

  require Logger

  @impl GenServer
  def init(config) do
    Logger.info("Initializing Oli.Vault")

    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: decode_env!("CLOAK_VAULT_KEY")}
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
end
