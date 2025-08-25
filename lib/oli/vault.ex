defmodule Oli.Vault do
  use Cloak.Vault, otp_app: :oli

  require Logger

  @impl GenServer
  def init(config) do
    Logger.info("Initializing Oli.Vault")

    {:ok, config}
  end
end
