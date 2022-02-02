defmodule Oli.Utils.ErrorLogger do
  require Logger

  def log_error(e, label \\ "Unexpected error") do
    Logger.error(label <> ": " <> Kernel.inspect(e))
  end
end
