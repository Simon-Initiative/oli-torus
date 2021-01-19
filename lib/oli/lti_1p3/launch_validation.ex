defmodule Oli.Lti_1p3.LaunchValidation do
  import Oli.Lti_1p3.Utils

  @message_validators [
    Oli.Lti_1p3.MessageValidators.ResourceMessageValidator
  ]

  # @type get_public_key_callback() :: (%Oli.Lti_1p3.Registration{}, String.t() -> {:ok, JOSE.JWK.t()})
  # @type providers() :: %{get_public_key: get_public_key_callback()}
  # @type validate_opts() :: [{:providers, providers()}]
  @type validate_opts() :: []

  @doc """
  Validates all aspects of an incoming LTI message launch and caches the launch params in the session if successful.
  """
  @spec validate(Plug.Conn.t(), validate_opts()) :: {:ok, Plug.Conn.t(), any()} | {:error, %{optional(atom()) => any(), reason: atom(), msg: String.t()}}
  def validate(conn, _opts \\ []) do
    # %{get_public_key: get_public_key} = Keyword.get(opts, :providers)

    with {:ok, conn} <- validate_oidc_state(conn),
         {:ok, conn, registration} <- validate_registration(conn),
         {:ok, key_set_url} <- registration_key_set_url(registration),
         {:ok, id_token} <- extract_param(conn, "id_token"),
         {:ok, conn, jwt_body} <- validate_jwt_signature(conn, id_token, key_set_url),
         {:ok, conn} <- validate_jwt_timestamps(conn, jwt_body),
         {:ok, conn} <- validate_deployment(conn, registration, jwt_body),
         {:ok, conn} <- validate_message(conn, jwt_body),
         {:ok, conn} <- validate_nonce(conn, jwt_body),
         {:ok, conn} <- cache_launch_params(conn, jwt_body)
    do
      {:ok, conn, jwt_body}
    end
  end

  # Validate that the state sent with an OIDC launch matches the state that was sent in the OIDC response
  # returns a boolean on whether it is valid or not
  defp validate_oidc_state(conn) do
    case Plug.Conn.get_session(conn, "state") do
      nil ->
        {:error, %{reason: :invalid_oidc_state, msg: "State from session is missing. Make sure cookies are enabled and configured correctly"}}
      session_state ->
        case conn.params["state"] do
          nil ->
            {:error, %{reason: :invalid_oidc_state, msg: "State from OIDC request is missing"}}
          request_state ->
            if request_state == session_state do
              {:ok, conn}
            else
              {:error, %{reason: :invalid_oidc_state, msg: "State from OIDC request does not match session"}}
            end
        end
    end
  end

  defp validate_registration(conn) do
    with {:ok, issuer, client_id} <- peek_issuer_client_id(conn) do
      case Oli.Institutions.get_registration_by_issuer_client_id(issuer, client_id) do
        nil ->
          {:error, %{reason: :invalid_registration, msg: "Registration with issuer \"#{issuer}\" and client id \"#{client_id}\" not found", issuer: issuer, client_id: client_id}}
        registration ->
          {:ok, conn, registration}
      end
    end
  end

  defp peek_issuer_client_id(conn) do
    with {:ok, jwt_string} <- extract_param(conn, "id_token"),
         {:ok, jwt_claims} <- peek_claims(jwt_string)
    do
      {:ok, jwt_claims["iss"], jwt_claims["aud"]}
    end
  end

  defp validate_nonce(conn, jwt_body) do
    case Oli.Lti_1p3.Nonces.create_nonce(%{value: jwt_body["nonce"]}) do
      {:ok, _nonce} ->
        {:ok, conn}
      {:error, %{ errors: [ value: { _msg, [{:constraint, :unique} | _]}]}} ->
        {:error, %{reason: :invalid_nonce, msg: "Duplicate nonce"}}
    end
  end

  defp validate_deployment(conn, registration, jwt_body) do
    deployment_id = jwt_body["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    deployment = Oli.Lti_1p3.get_deployment(registration, deployment_id)

    case deployment do
      nil ->
        {:error, %{reason: :invalid_deployment, msg: "Deployment with id \"#{deployment_id}\" not found", registration_id: registration.id, deployment_id: deployment_id}}
      _deployment ->
        {:ok, conn}
    end
  end

  defp validate_message(conn, jwt_body) do
    case jwt_body["https://purl.imsglobal.org/spec/lti/claim/message_type"] do
      nil ->
        {:error, %{reason: :invalid_message_type, msg: "Missing message type"}}
      message_type ->
        # no more than one message validator should apply for a given mesage,
        # so use the first validator we find that applies
        validation_result = case Enum.find(@message_validators, fn mv -> mv.can_validate(jwt_body) end) do
          nil -> nil
          validator -> validator.validate(jwt_body)
        end

        case validation_result do
          nil ->
            {:error, %{reason: :invalid_message_type, msg: "Invalid or unsupported message type \"#{message_type}\""}}
          {:error, error} ->
            {:error, %{reason: :invalid_message, msg: "Message validation failed: (\"#{message_type}\") #{error}"}}
          _ ->
            {:ok, conn}
        end
    end
  end

  defp cache_launch_params(conn, jwt_body) do
    # LTI 1.3 params are too big to store in the session cookie. Therefore, we must
    # cache all lti_params key'd on the sub value in database for use in other views
    Oli.Lti_1p3.cache_lti_params!(jwt_body["sub"], jwt_body)

    conn = conn
    |> Plug.Conn.put_session(:lti_1p3_sub, jwt_body["sub"])

    {:ok, conn}
  end

end
