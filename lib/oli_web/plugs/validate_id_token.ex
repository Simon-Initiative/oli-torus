defmodule Oli.Plugs.ValidateIdToken do
  import Oli.{HTTP, Utils}
  import OliWeb.ViewHelpers, only: [redirect_with_error: 3]

  alias Oli.Institutions
  alias Oli.Institutions.SsoJwk

  @jwks_relative_path "/.well-known/jwks.json"

  def init(opts), do: opts

  def call(conn, _opts) do
    with jwt when not is_nil(jwt) <- conn.params["id_token"] || conn.params["cognito_id_token"],
         {:ok, jwk} <- get_jwk(jwt),
         {true, %{fields: jwt_fields}, _} <- JOSE.JWT.verify_strict(jwk, ["RS256"], jwt) do
      Plug.Conn.assign(conn, :claims, jwt_fields)
    else
      nil ->
        redirect_with_error(conn, get_error_url(conn.params), "Missing id token")

      {false, _, _} ->
        redirect_with_error(conn, get_error_url(conn.params), "Unable to verify credentials")

      {:error, error} ->
        redirect_with_error(conn, get_error_url(conn.params), snake_case_to_friendly(error))
    end
  end

  defp get_jwk(jwt) do
    with {:ok, %{"kid" => kid}} <- Joken.peek_header(jwt),
         {:ok, %{"iss" => issuer}} <- Joken.peek_claims(jwt),
         {:ok, sso_jwk} <- find_or_fetch_jwk(kid, issuer) do
      {:ok, JOSE.JWK.from_pem(sso_jwk.pem)}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp find_or_fetch_jwk(kid, issuer) do
    case Institutions.get_jwk_by(%{kid: kid}) do
      %SsoJwk{} = jwk ->
        {:ok, jwk}

      nil ->
        get_cognito_jwks(kid, issuer)
    end
  end

  defp get_cognito_jwks(kid, issuer) do
    url = issuer <> @jwks_relative_path

    case http().get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Poison.decode!()
        |> JOSE.JWK.from_map()
        |> persist_keys(kid)

      {:ok, %HTTPoison.Response{}} ->
        {:error, "Error retrieving the JWKS"}
    end
  end

  defp persist_keys(%JOSE.JWK{keys: {_, keys}}, kid) do
    key =
      keys
      |> Enum.map(&Institutions.build_jwk/1)
      |> Institutions.insert_bulk_jwks()
      |> Enum.find(fn %SsoJwk{kid: jwk_kid} -> jwk_kid == kid end)

    if key, do: {:ok, key}, else: {:error, "Missing Key"}
  end

  defp persist_keys(_, _), do: {:error, "Error retrieving the JWKS"}

  defp get_error_url(%{"error_url" => error_url}), do: error_url
  defp get_error_url(_params), do: "/unauthorized"
end
