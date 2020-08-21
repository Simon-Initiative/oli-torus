defmodule Oli.Lti_1_3.LaunchValidation do
  @spec validate(Plug.Conn.t(), String.t()) :: {:ok} | {:error, any()}
  def validate(conn, path) do

    with {:ok, conn, errors} <- validate_oidc_launch(conn, []) do
      {:ok}
    else
      {:error, errors} -> {:error, errors}
    end

    # # initialize error list
    # errors = case conn.assigns["error"] do
    #   nil ->
    #     []
    #   error ->
    #     # if platform returned an error, add it to errors
    #     ["Login Response was rejected: #{error}"]
    # end

    # errors = if is_valid_oidc_launch?(conn) do
    #   # If valid, save OIDC Launch Request for later reference during current session
    #   Plug.Conn.put_session(conn, :payload, conn.params)

    #   # Decode the JWT into header, payload, and signature
    #   jwt_string =  conn.params["id_token"]
    #   decoded = JOSE.JWT.

    #   errors
    # else
    #   ["Invalid OIDC Launch Request: state mismatch" | errors]
    # end

    # if Enum.count(errors) > 0 do
    #   {:error, errors}
    # else
    #   {:ok}
    # end
  end

  # Validate that the state sent with an OIDC launch matches the state that was sent in the OIDC response
  # returns a boolean on whether it is valid or not
  defp validate_oidc_launch(conn, errors) do
    case Plug.Conn.get_session(conn, :login_response) do
      %{ :state => state } ->
        if conn.params["state"] == state do
          {:ok, conn, errors}
        else
          {:error, ["Invalid OIDC Launch Request: state mismatch" | errors]}
        end
      _ ->
        {:error, ["Invalid OIDC Launch Request: state is not set in current session" | errors]}
    end
  end
end
