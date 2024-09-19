defmodule Oli.Plugs.MaybeLoadLtiParams do
  import Plug.Conn

  alias OliWeb.Common.LtiSession
  alias Oli.Lti.LtiParams

  def init(opts), do: opts

  def call(conn, _opts) do
    case LtiSession.get_session_lti_params(conn) do
      nil ->
        conn

      lti_params_id ->
        # load cached lti params from database
        load_lti_params(conn, lti_params_id)
    end
  end

  defp load_lti_params(conn, lti_params_id) do
    case LtiParams.get_lti_params(lti_params_id) do
      nil ->
        conn

      %{params: params} ->
        assign(conn, :lti_params, params)
    end
  end
end
