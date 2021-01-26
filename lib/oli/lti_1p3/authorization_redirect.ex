defmodule Oli.Lti_1p3.AuthorizationRedirect do
  import Oli.Lti_1p3.Utils

  alias Oli.Lti_1p3.PlatformInstances
  alias Oli.Lti_1p3.LoginHint
  alias Oli.Lti_1p3.LoginHints

  def authorize_redirect(conn, params) do
    case PlatformInstances.get_platform_instance_by_client_id(params["client_id"]) do
      nil ->
        {:error, %{reason: :client_not_registered, msg: "No platform exists with client id '#{params["client_id"]}'"}}

      platform_instance ->
        client_id = platform_instance.client_id

        # TODO: decide how to handle deployments, for now just use "1"
        deployment_id = "1"

        # perform authentication response validation per LTI 1.3 specification
        # https://www.imsglobal.org/spec/security/v1p0/#step-3-authentication-response
        with {:ok} <- validate_oidc_params(params),
             {:ok} <- validate_oidc_scope(params),
             {:ok} <- validate_current_user(conn, params),
             {:ok} <- validate_client_id(params, client_id)
        do
          active_jwk = get_active_jwk()
          issuer = Oli.Utils.get_base_url()
          custom_header = %{"kid" => active_jwk.kid}
          signer = Joken.Signer.create("RS256", %{"pem" => active_jwk.pem}, custom_header)

          {:ok, claims} = Joken.Config.default_claims(iss: issuer, aud: client_id)
            |> Joken.generate_claims(%{
              "nonce" => UUID.uuid4(),
              "sub" => "test sub",
              "name" => "test name",
              "given_name" => "test given_name",
              "family_name" => "test family_name",
              "middle_name" => "test middle_name",

              # TODO: more claims data, e.g. test/support/lti_1p3_test_helpers.ex:104
              " https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment_id,
            })

          {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

          state = params["state"]
          redirect_uri = params["redirect_uri"]

          {:ok, redirect_uri, state, id_token}
        end
    end
  end

  defp validate_oidc_params(params) do
    required_param_keys = [
      "client_id",
      "login_hint",
      "lti_message_hint",
      "nonce",
      "prompt",
      "redirect_uri",
      "response_mode",
      "response_type",
      "scope",
    ]

    case Enum.filter(required_param_keys, fn required_key -> !Map.has_key?(params, required_key) end) do
      [] ->
        {:ok}
      missing_params->
        {:error, %{reason: :invalid_oidc_params, msg: "Invalid OIDC params. The following parameters are missing: #{Enum.join(missing_params, ",")}", missing_params: missing_params}}
    end

  end

  defp validate_oidc_scope(params) do
    if params["scope"] == "openid" do
      {:ok}
    else
      {:error, %{reason: :invalid_oidc_scope, msg: "Invalid OIDC scope: #{params["scope"]}. Scope must be 'openid'"}}
    end
  end

  # TODO: refactor to be more general, remove author
  defp validate_current_user(conn, params) do
    case LoginHints.get_login_hint_by_value(params["login_hint"]) do
      %LoginHint{user_id: user_id, author_id: nil} ->
        if conn.assigns[:current_user].id == user_id do
          {:ok}
        else
          {:error, %{reason: :no_user_session, msg: "No user session"}}
        end

      %LoginHint{user_id: nil, author_id: author_id} ->
        if conn.assigns[:current_author].id == author_id do
          {:ok}
        else
          {:error, %{reason: :no_user_session, msg: "No author session"}}
        end

      _ ->
        {:error, %{reason: :invalid_login_hint, msg: "Login hint must be linked with an active user session"}}
    end
  end

  defp validate_client_id(params, client_id) do
    if params["client_id"] == client_id do
      {:ok}
    else
      {:error, %{reason: :unauthorized_client, msg: "Client not authorized in requested context"}}
    end
  end

end
