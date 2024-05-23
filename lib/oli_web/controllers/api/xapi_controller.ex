defmodule OliWeb.Api.XAPIController do
  @moduledoc """
  Endpoints to allow client-side posting of xapi statements.
  """
  import OliWeb.Api.Helpers
  alias Oli.Analytics.XAPI

  use OliWeb, :controller

  def emit(conn, %{"event" => event, "key" => key}) do

    current_user = conn.assigns[:current_user]

    # Add the host_name to the event, which is used to construct the xapi statement
    event = Map.put(event, "host_name", host_name())
    |> Map.put("key", key)

    IO.inspect event

    case XAPI.construct_bundle(event, current_user.id) do
      {:ok, bundle} ->
        XAPI.emit(bundle)
        json(conn, %{"result" => "success"})
      {:error, e} ->
        error(conn, e, "error")
    end

  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

end
