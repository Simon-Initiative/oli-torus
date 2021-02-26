defmodule Oli.Plugs.LoadLtiParams do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Common.LtiSession
  alias Lti_1p3

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.path_params do
      %{"section_slug" => section_slug} ->
        case LtiSession.get_section_params(conn, section_slug) do
          nil ->
            lms_signin_required(conn)

          lti_params_key ->
            # load cached lti params from database
            fetch_lti_params(conn, lti_params_key)
        end

      _ ->
        case LtiSession.get_user_params(conn) do
          nil ->
            lms_signin_required(conn)

          lti_params_key ->
            # load cached lti params from database
            fetch_lti_params(conn, lti_params_key)
        end
    end

  end

  defp fetch_lti_params(conn, lti_params_key) do
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
    |> render("signin_required.html")
    |> halt()
  end

end
