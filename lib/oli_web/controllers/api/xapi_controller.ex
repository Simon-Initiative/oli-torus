defmodule OliWeb.Api.XAPIController do
  @moduledoc """
  Endpoints to allow client-side posting of xapi statements.
  """
  alias Oli.Analytics.XAPI
  require Logger

  use OliWeb, :controller

  def emit(conn, %{"event" => event, "key" => key}) do
    current_user = conn.assigns[:current_user]

    # Add the host_name to the event, which is used to construct the xapi statement
    event =
      Map.put(event, "host_name", host_name())
      |> Map.put("key", key)

    case XAPI.construct_bundle(event, current_user.id) do
      {:ok, bundle} ->
        XAPI.emit(bundle)
        json(conn, %{"result" => "success"})

      {:error, e} ->
        Logger.error("Error constructing xapi bundle: #{inspect(e)}")
        Oli.Utils.Appsignal.capture_error("Error constructing xapi bundle: #{inspect(e)}")

        json(conn, %{"result" => "failure", "reason" => e})
    end
  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end
end
