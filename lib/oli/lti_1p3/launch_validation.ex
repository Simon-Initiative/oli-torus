defmodule Oli.Lti_1p3.LaunchValidation do
  @message_validators [
    Oli.Lti_1p3.MessageValidators.ResourceMessageValidator
  ]

  @doc """
  Validates all aspects of an incoming LTI message launch and caches the launch params in the session if successful.
  """
  @spec validate(Plug.Conn.t()) :: {:ok} | {:error, String.t()}
  def validate(conn) do
    with {:ok, conn} <- validate_oidc_state(conn),
         {:ok, conn, jwt} <- validate_jwt_format(conn),
         {:ok, conn, registration} <- validate_registration(conn, jwt),
         {:ok, conn} <- validate_jwt_signature(conn, registration, jwt),
         {:ok, conn} <- validate_nonce(conn, jwt),
         {:ok, conn} <- validate_deployment(conn, registration, jwt),
         {:ok, conn} <- validate_message(conn, jwt),
         {:ok, _conn} <- cache_launch_params(conn)
    do
      {:ok}
    else
      {:error, error} -> {:error, error}
    end
  end

  # Validate that the state sent with an OIDC launch matches the state that was sent in the OIDC response
  # returns a boolean on whether it is valid or not
  defp validate_oidc_state(conn) do
    case Plug.Conn.get_session(conn, :login_response) do
      %{:state => state} ->
        if conn.params["state"] == state do
          {:ok, conn}
        else
          {:error, "State from OIDC request does not match"}
        end
      _ ->
        {:error, "State from OIDC request is missing"}
    end
  end

  defp validate_registration(conn, jwt) do
    case Oli.Lti_1p3.get_registration_by_kid(jwt["header"]["kid"]) do
      {:ok, registration} ->
        {:ok, conn, registration}
      _ ->
        {:error, "Registration with kid not found"}
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

  defp jwt_from_string(jwt_string) do
    try do
      {:ok, JOSE.JWT.from(jwt_string)}
    rescue
      _ ->
        {:error, "Invalid id_token"}
    end
  end

  defp validate_jwt_format(conn) do
    with {:ok, jwt_string} <- decode_id_token(conn),
         {:ok, jwt} <- jwt_from_string(jwt_string)
    do
      {:ok, conn, jwt}
    else
      {:error, e} -> {:error, e}
    end
  end

  @spec get_public_key(%Oli.Lti_1p3.Registration{}, String.t()) :: {:ok, JOSE.JWK.t()}
  defp get_public_key(%Oli.Lti_1p3.Registration{key_set_url: key_set_url}, kid) do
    public_key_set = case HTTPoison.get(key_set_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)
      _ ->
        {:error, "Failed to fetch public key from registered platform url"}
    end

    public_key = Enum.find(public_key_set["keys"], fn key -> key["kid"] == kid end)
    |> JOSE.JWK.from

    {:ok, public_key}
  end

  defp validate_jwt_signature(conn, registration, jwt) do
    with {:ok, jwt_string} <- decode_id_token(conn),
         {:ok, public_key} <- get_public_key(registration, jwt["header"]["kid"])
    do
      # TODO: REMOVE
      # JOSE.JWT.verify_strict(public_key, "RS256", jwt)

      case JOSE.JWT.verify_strict(public_key, "RS256", jwt_string) do
        {true, _} ->
          {:ok, conn}
        _ ->
          {:error, "Invalid signature on id_token"}
      end
    else
      {:error, e} -> {:error, e}
    end
  end

  defp validate_nonce(conn, jwt) do
    if Oli.Lti_1p3.NonceCacheAgent.has(jwt["body"]["nonce"]) do
      {:error, "Duplicate nonce"}
    else
      Oli.Lti_1p3.NonceCacheAgent.put(jwt["body"]["nonce"])
      {:ok, conn}
    end
  end

  defp validate_deployment(conn, registration, jwt) do
    deployment_id = jwt["body"]["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
    deployment = Oli.Lti_1p3.get_deployment(registration, deployment_id)

    case deployment do
      nil ->
        {:error, "Unable to find deployment"}
      _deployment ->
        {:ok, conn}
    end
  end

  defp validate_message(conn, jwt) do
    case jwt["body"]["https://purl.imsglobal.org/spec/lti/claim/message_type"] do
      nil ->
        {:error, "Invalid message type"}
      message_type ->
        # no more than one message validator should apply for a given mesage,
        # so use the first validator we find that applies
        validation_result = case Enum.find(@message_validators, fn mv -> mv.can_validate(jwt["body"]) end) do
          nil -> nil
          validator -> validator.validate(jwt["body"])
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
    Plug.Conn.put_session(conn, :lti1p3_launch_params, conn.params)
    {:ok, conn}
  end

end
