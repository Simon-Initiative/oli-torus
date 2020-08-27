defmodule Oli.Lti_1p3.LaunchValidation do
  @message_validators [
    Oli.Lti_1p3.MessageValidators.ResourceMessageValidator
  ]

  @type get_public_key_callback() :: (%Oli.Lti_1p3.Registration{}, String.t() -> {:ok, JOSE.JWK.t()})

  @doc """
  Validates all aspects of an incoming LTI message launch and caches the launch params in the session if successful.
  """
  @spec validate(Plug.Conn.t(), get_public_key_callback()) :: {:ok, Plug.Conn.t()} | {:error, String.t()}
  def validate(conn, get_public_key) do
    with {:ok, conn} <- validate_oidc_state(conn),
         {:ok, kid} <- peek_jwt_kid(conn),
         {:ok, conn, registration} <- validate_registration(conn, kid),
         {:ok, conn, jwt_body} <- validate_jwt(conn, registration, kid, get_public_key),
         {:ok, conn} <- validate_token_timestamps(conn, jwt_body),
         {:ok, conn} <- validate_nonce(conn, jwt_body),
         {:ok, conn} <- validate_deployment(conn, registration, jwt_body),
         {:ok, conn} <- validate_message(conn, jwt_body),
         {:ok, conn} <- cache_launch_params(conn)
    do
      {:ok, conn}
    end
  end

  # Validate that the state sent with an OIDC launch matches the state that was sent in the OIDC response
  # returns a boolean on whether it is valid or not
  defp validate_oidc_state(conn) do
    case Plug.Conn.get_session(conn, :lti1p3_state) do
      nil ->
        {:error, "State from OIDC request is missing"}
      state ->
        if conn.params["state"] == state do
          {:ok, conn}
        else
          {:error, "State from OIDC request does not match"}
        end
    end
  end

  defp validate_registration(conn, kid) do
    case Oli.Lti_1p3.get_registration_by_kid(kid) do
      nil ->
        {:error, "Registration with kid \"#{kid}\" not found"}
        registration ->
        {:ok, conn, registration}
    end
  end

  defp decode_id_token(conn) do
    case conn.params["id_token"] do
      nil ->
        {:error, "Missing id_token"}
      id_token ->
        {:ok, id_token}
    end
  end

  defp peek_jwt_kid(conn) do
    with {:ok, jwt_string} <- decode_id_token(conn),
         {:ok, jwt_body} <- Joken.peek_header(jwt_string)
    do
      {:ok, jwt_body["kid"]}
    end
  end

  # TODO: REMOVE
  # @spec get_public_key(%Oli.Lti_1p3.Registration{}, String.t()) :: {:ok, JOSE.JWK.t()}
  # defp get_public_key(%Oli.Lti_1p3.Registration{key_set_url: key_set_url}, kid) do
  #   public_key_set = case HTTPoison.get(key_set_url) do
  #     {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
  #       Jason.decode!(body)
  #     _ ->
  #       {:error, "Failed to fetch public key from registered platform url"}
  #   end

  #   public_key = Enum.find(public_key_set["keys"], fn key -> key["kid"] == kid end)
  #   |> JOSE.JWK.from

  #   {:ok, public_key}
  # end

  defp validate_jwt(conn, registration, kid, get_public_key) do
    with {:ok, jwt_string} <- decode_id_token(conn),
         {:ok, public_key} <- get_public_key.(registration, kid)
    do
      {_kty, pk} = JOSE.JWK.to_map(public_key)

      signer = Joken.Signer.create("RS256", pk)

      case Joken.verify_and_validate(%{}, jwt_string, signer) do
        {:ok, jwt} ->
          {:ok, conn, jwt}
        {:error, :signature_error} ->
          {:error, "Invalid signature on id_token"}
        error -> error
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
            {:error, "Token exp is expired"}
          {false, _} ->
            {:error, "Token iat is invalid"}
          _ ->
            {:error, "Token is exp and iat are invalid"}
        end
      end
    rescue
      _error -> {:error, "Timestamps are invalid"}
    end
  end

  defp validate_nonce(conn, jwt_body) do
    if Oli.Lti_1p3.NonceCacheAgent.has(jwt_body["nonce"]) do
      {:error, "Duplicate nonce"}
    else
      Oli.Lti_1p3.NonceCacheAgent.put(jwt_body["nonce"])
      {:ok, conn}
    end
  end

  defp validate_deployment(conn, registration, jwt_body) do
    deployment_id = jwt_body["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    deployment = Oli.Lti_1p3.get_deployment(registration, deployment_id)

    case deployment do
      nil ->
        {:error, "Deployment with id \"#{deployment_id}\" not found"}
      _deployment ->
        {:ok, conn}
    end
  end

  defp validate_message(conn, jwt_body) do
    case jwt_body["https://purl.imsglobal.org/spec/lti/claim/message_type"] do
      nil ->
        {:error, "Missing message type"}
      message_type ->
        # no more than one message validator should apply for a given mesage,
        # so use the first validator we find that applies
        validation_result = case Enum.find(@message_validators, fn mv -> mv.can_validate(jwt_body) end) do
          nil -> nil
          validator -> validator.validate(jwt_body)
        end

        case validation_result do
          nil ->
            {:error, "Invalid or unsupported message type \"#{message_type}\""}
          {:error, error} ->
            {:error, "Message validation failed: (\"#{message_type}\") #{error}"}
          _ ->
            {:ok, conn}
        end
    end
  end

  defp cache_launch_params(conn) do
    conn = conn
    |> Plug.Conn.put_session(:lti1p3_launch_params, conn.params)

    {:ok, conn}
  end

end
