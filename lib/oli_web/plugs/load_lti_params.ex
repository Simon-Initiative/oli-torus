defmodule Oli.Plugs.LoadLtiParams do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Lti_1p3

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :lti_1p3_sub) do
      nil ->
        lms_signin_required(conn)
      sub ->
        # load cached lti params from database
        case Lti_1p3.fetch_lti_params(sub) do
          nil ->
            lms_signin_required(conn)
          %{data: data} ->
            assign(conn, :lti_params, data)
        end
    end
  end

  defp lms_signin_required(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> render("signin_required.html")
    |> halt()
  end

end
