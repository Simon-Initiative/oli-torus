defmodule Oli.Lti_1p3.OidcLogin do
  import Plug.Conn

  def oidc_login_redirect_url(conn, params) do
    with {:ok, conn, _issuer, login_hint, registration} <- validate_oidc_login(conn) do
      # craft OIDC auth response
      # create unique state
      state =  UUID.uuid4()
      conn = conn
        |> put_session("state", state)

      query_params = %{
        "scope" => "openid",
        "response_type" => "id_token",
        "response_mode" => "form_post",
        "prompt" => "none",
        "client_id" => params["client_id"],
        "redirect_uri" => params["target_link_uri"],
        "state" => state,
        "nonce" => UUID.uuid4(),
        "login_hint" => login_hint,
      }

      # pass back LTI message hint if given
      query_params = case conn.params["lti_message_hint"] do
        nil -> query_params
        lti_message_hint -> Map.put_new(query_params, "lti_message_hint", lti_message_hint)
      end

      auth_login_return_url = registration.auth_login_url <> "?" <> URI.encode_query(query_params)

      {:ok, conn, auth_login_return_url}
    end
  end

  defp validate_oidc_login(conn) do
    with {:ok, conn, issuer} <- validate_issuer(conn),
         {:ok, conn, login_hint} <- validate_login_hint(conn),
         {:ok, conn, registration} <- validate_registration(conn)
    do
      {:ok, conn, issuer, login_hint, registration}
    end
  end

  defp validate_issuer(conn) do
    case conn.params["iss"] do
      nil -> {:error, %{reason: :missing_issuer, msg: "Request does not have an issuer (iss)"}}
      issuer -> {:ok, conn, issuer}
    end
  end

  defp validate_login_hint(conn) do
    case conn.params["login_hint"] do
      nil -> {:error, %{reason: :missing_login_hint, msg: "Request does not have a login hint (login_hint)"}}
      login_hint -> {:ok, conn, login_hint}
    end
  end

  defp validate_registration(conn) do
    issuer = conn.params["iss"]
    client_id = conn.params["client_id"]

    case Oli.Institutions.get_registration_by_issuer_client_id(issuer, client_id) do
      nil ->
        {:error, %{
          reason: :invalid_registration,
          msg: "Registration with issuer \"#{issuer}\" and client id \"#{client_id}\" not found",
          issuer: issuer,
          client_id: client_id,
        }}
      registration ->
        {:ok, conn, registration}
    end
  end
end
