defmodule Oli.Lti_1p3.LaunchValidation do
  @message_validators [
    Oli.Lti_1p3.MessageValidators.ResourceMessageValidator
  ]

  @type get_public_key_callback() :: (%Oli.Lti_1p3.Registration{}, String.t() -> {:ok, JOSE.JWK.t()})

  @doc """
  Validates all aspects of an incoming LTI message launch and caches the launch params in the session if successful.
  """
  @spec validate(Plug.Conn.t(), get_public_key_callback()) :: {:ok, Plug.Conn.t(), any()} | {:error, %{optional(atom()) => any(), reason: atom(), msg: String.t()}}
  def validate(conn, get_public_key) do
    with {:ok, conn} <- validate_oidc_state(conn),
         {:ok, kid} <- peek_jwt_kid(conn),
         {:ok, conn, registration} <- validate_registration(conn, kid),
         {:ok, conn, jwt_body} <- validate_jwt(conn, registration, kid, get_public_key),
         {:ok, conn} <- validate_token_timestamps(conn, jwt_body),
         {:ok, conn} <- validate_nonce(conn, jwt_body),
         {:ok, conn} <- validate_deployment(conn, registration, jwt_body),
         {:ok, conn} <- validate_message(conn, jwt_body),
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

  defp validate_registration(conn, kid) do
    case Oli.Lti_1p3.get_registration_by_kid(kid) do
      nil ->
        {:error, %{reason: :invalid_registration, msg: "Registration with kid \"#{kid}\" not found", kid: kid}}
        registration ->
        {:ok, conn, registration}
    end
  end

  defp extract_id_token(conn) do
    case conn.params["id_token"] do
      nil ->
        {:error, %{reason: :missing_id_token, msg: "Missing id_token"}}
      id_token ->
        {:ok, id_token}
    end
  end

  defp peek_header(jwt_string) do
    case Joken.peek_header(jwt_string) do
      {:ok, jwt_body} ->
        {:ok, jwt_body}
      {:error, reason} ->
        {:error, %{reason: reason, msg: "Invalid id_token"}}
    end
  end

  defp peek_jwt_kid(conn) do
    with {:ok, jwt_string} <- extract_id_token(conn),
         {:ok, jwt_body} <- peek_header(jwt_string)
    do
      {:ok, jwt_body["kid"]}
    end
  end

  defp validate_jwt(conn, registration, kid, get_public_key) do
    with {:ok, jwt_string} <- extract_id_token(conn),
         {:ok, public_key} <- get_public_key.(registration, kid)
    do
      {_kty, pk} = JOSE.JWK.to_map(public_key)

      signer = Joken.Signer.create("RS256", pk)

      case Joken.verify_and_validate(%{}, jwt_string, signer) do
        {:ok, jwt} ->
          {:ok, conn, jwt}
        {:error, reason} ->
          {:error, %{reason: reason, msg: "Invalid id_token"}}
      end
    end
  end

  defp validate_token_timestamps(conn, jwt_body) do
    try do
      case {Timex.from_unix(jwt_body["exp"]), Timex.from_unix(jwt_body["iat"])} do
      {exp, iat} ->
        now = Timex.now()

        # check if token is expired and/or issued at invalid time
        case {Timex.before?(exp, now), Timex.after?(iat, now)} do
          {false, false} ->
            {:ok, conn}
          {_, false} ->
            {:error, %{reason: :invalid_token_timstamp, msg: "Token exp is expired"}}
          {false, _} ->
            {:error, %{reason: :invalid_token_timstamp, msg: "Token iat is invalid"}}
          _ ->
            {:error, %{reason: :invalid_token_timstamp, msg: "Token exp and iat are invalid"}}
        end
      end
    rescue
      _error -> {:error, %{reason: :invalid_token_timstamp, msg: "Timestamps are invalid"}}
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
        {:error, %{reason: :invalid_deployment, msg: "Deployment with id \"#{deployment_id}\" not found", deployment_id: deployment_id}}
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
    Oli.Lti_1p3.cache_lti_params(jwt_body["sub"], jwt_body)

    conn = conn
    |> Plug.Conn.put_session(:lti_1p3_sub, jwt_body["sub"])

    {:ok, conn}
  end

end
