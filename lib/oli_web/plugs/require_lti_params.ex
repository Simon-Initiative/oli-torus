defmodule Oli.Plugs.RequireLtiParams do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Common.LtiSession
  alias Oli.Lti.LtiParams

  def init(opts), do: opts

  def call(conn, _opts) do
    case LtiSession.get_session_lti_params(conn) do
      nil ->
        lms_signin_required(conn)

      lti_params_id ->
        # load cached lti params from database
        load_lti_params(conn, lti_params_id)
    end
  end

  defp load_lti_params(conn, lti_params_id) do
    case LtiParams.get_lti_params(lti_params_id) do
      nil ->
        lms_signin_required(conn)

      %{params: params} ->
        assign(conn, :lti_params, params)
    end
  end

  defp lms_signin_required(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(401)
    |> render("lms_signin_required.html")
    |> halt()
  end
end
