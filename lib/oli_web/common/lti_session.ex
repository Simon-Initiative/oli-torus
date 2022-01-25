defmodule OliWeb.Common.LtiSession do
  @moduledoc """
  A module for managing lti session params.

  A separate plug uses get_session_lti_params to retrieve and set :lti_params in assigns
  """
  import Plug.Conn

  @doc """
  Puts the lti params id for the current session
  """
  def put_session_lti_params(conn, lti_params_id) do
    conn
    |> put_session(:lti_params_id, lti_params_id)
  end

  @doc """
  Gets the lti params id for the current session
  """
  def get_session_lti_params(conn) do
    conn
    |> get_session(:lti_params_id)
  end
end
