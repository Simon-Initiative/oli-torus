defmodule Oli.Lti_1p3.Utils do
  alias Oli.Lti_1p3.Registration

  def default_config(), do: Application.get_env(:oli, :lti_1p3, [http_client: HTTPoison])

  defp http(), do: Keyword.get(default_config(), :http_client)

  def registration_key_set_url(%Registration{key_set_url: key_set_url}) do
    {:ok, key_set_url}
  end

  def extract_param(conn, param) do
    case conn.params[param] do
      nil ->
        {:error, %{reason: :missing_param, msg: "Missing #{param}"}}
      param ->
        {:ok, param}
    end
  end

  def peek_header(jwt_string) do
    case Joken.peek_header(jwt_string) do
      {:ok, header} ->
        {:ok, header}
      {:error, reason} ->
        {:error, %{reason: reason, msg: "Invalid JWT"}}
    end
  end

  def peek_claims(jwt_string) do
    case Joken.peek_claims(jwt_string) do
      {:ok, claims} ->
        {:ok, claims}
      {:error, reason} ->
        {:error, %{reason: reason, msg: "Invalid JWT"}}
    end
  end

  def peek_jwt_kid(jwt_string) do
    with {:ok, jwt_body} <- peek_header(jwt_string)
    do
      {:ok, jwt_body["kid"]}
    end
  end

  def validate_jwt_signature(conn, jwt_string, key_set_url) do
    with {:ok, kid} <- peek_jwt_kid(jwt_string),
         {:ok, public_key} <- fetch_public_key(key_set_url, kid)
    do
      {_kty, pk} = JOSE.JWK.to_map(public_key)

      signer = Joken.Signer.create("RS256", pk)

      case Joken.verify_and_validate(%{}, jwt_string, signer) do
        {:ok, jwt} ->
          {:ok, conn, jwt}
        {:error, reason} ->
          {:error, %{reason: reason, msg: "Invalid JWT"}}
      end
    end
  end

  def validate_jwt_timestamps(conn, jwt_body) do
    try do
      case {Timex.from_unix(jwt_body["exp"]), Timex.from_unix(jwt_body["iat"])} do
      {exp, iat} ->
        # get the current time with a buffer of a few seconds to account for clock skew and rounding
        now = Timex.now()
        buffer_sec = 2
        a_few_seconds_ago = now |> Timex.subtract(Timex.Duration.from_seconds(buffer_sec))
        a_few_seconds_ahead = now |> Timex.add(Timex.Duration.from_seconds(buffer_sec))

        # check if jwt is expired and/or issued at invalid time
        case {Timex.before?(exp, a_few_seconds_ago), Timex.after?(iat, a_few_seconds_ahead)} do
          {false, false} ->
            {:ok, conn}
          {_, false} ->
            {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT exp is expired"}}
          {false, _} ->
            {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT iat is invalid"}}
          _ ->
            {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT exp and iat are invalid"}}
        end
      end
    rescue
      _error -> {:error, %{reason: :invalid_jwt_timestamp, msg: "Timestamps are invalid"}}
    end
  end

  def fetch_public_key(key_set_url, kid) do
    public_key_set = case http().get(key_set_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)
      error ->
        error
    end

    case Enum.find(public_key_set["keys"], fn key -> key["kid"] == kid end) do
      nil ->
        {:error, %{reason: :key_not_found, msg: "Key with kid #{kid} not found in the fetched list of public keys"}}

      public_key_json ->
        public_key = public_key_json
          |> JOSE.JWK.from

        {:ok, public_key}
    end
  end
end
