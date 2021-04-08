defmodule Oli.Plugs.RequireLtiParams do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Common.LtiSession
  alias Lti_1p3

  def init(opts), do: opts

  def call(conn, _opts) do
    case LtiSession.get_user_params(conn) do
      nil ->
        lms_signin_required(conn)

      lti_params_key ->
        # load cached lti params from database
        load_lti_params(conn, lti_params_key)
    end
  end

  defp load_lti_params(conn, lti_params_key) do
    case Lti_1p3.Tool.get_lti_params_by_key(lti_params_key) do
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
    |> render("signin_required.html")
    |> halt()
  end
end
