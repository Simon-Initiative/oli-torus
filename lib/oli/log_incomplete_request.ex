defmodule Oli.LogIncompleteRequestHandler do
  alias Oli.Utils.Appsignal

  require Logger

  def handle_event([:cowboy, :request, :early_error], _response, request, nil) do
    e = "Incomplete HTTP Request: " <> Kernel.inspect(request)

    Appsignal.capture_error(e)

    Logger.error(e)
  end
end
