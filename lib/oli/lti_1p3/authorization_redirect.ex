defmodule Oli.Lti_1p3.AuthorizationRedirect do
  import Oli.Lti_1p3.Utils

  alias Oli.Lti_1p3.PlatformInstances

  # TODO
  def authorize_redirect(conn, params) do

    # TODO: REMOVE
    IO.inspect params

    case PlatformInstances.get_platform_instance_by_client_id(params["client_id"]) do
      nil ->
        {:error, %{reason: :client_not_registered, msg: "No platform exists with client id '#{params["client_id"]}'"}}

      platform_instance ->
        keyset_url = platform_instance.keyset_url
        client_id = platform_instance.client_id

        # TODO: decide how to handle deployments
        deployment_id = "1"

        # perform authentication response validation per LTI 1.3 specification
        # https://www.imsglobal.org/spec/security/v1p0/#authentication-response-validation-0
        with {:ok, jwt_string} <- extract_param(conn, "state"),
            # validate signature
            # TODO: allow tool to specify an algorithm in the alg header parameter of the JOSE Header
            {:ok, _conn, state_jwt} <- validate_jwt_signature(conn, jwt_string, keyset_url),

            _ <- IO.inspect(state_jwt, label: "state_jwt"),

            # validate the issuer claim ('iss') matches the client_id for tool
            {:ok} <- validate_issuer(state_jwt, client_id),

            # validate that the audience claim ('aud') contains its advertised issuer URL
            {:ok} <- validate_audience(state_jwt, Oli.Utils.get_base_url()),

            # TODO (SHOULD): if the token contains multiple audiences, verify that the authorized party claim ('azp') is present
            # and that its issuer URL is the claim value.

            # validate the token is not expired ('exp) and issued at is valid ('iat')
            {:ok} <- validate_timestamps(state_jwt),

            # validate nonce. because nonce uniqueness is scoped to a particular platform instance
            # use the platform instance's unique client_id to scope the nonce validation to only that domain
            {:ok} <- validate_nonce(state_jwt, "platform_instance_#{client_id}")
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

          IO.inspect claims, label: "claims"

          {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

          state = params["state"]
          redirect_uri = params["redirect_uri"]

          {:ok, redirect_uri, state, id_token}
        end
    end
  end

end
