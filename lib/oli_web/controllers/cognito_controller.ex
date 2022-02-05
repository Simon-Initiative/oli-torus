defmodule OliWeb.CognitoController do
  use OliWeb, :controller

  import Oli.{HTTP, Utils}

  require Logger

  alias Oli.{Accounts, Groups, Institutions}
  alias Oli.Institutions.SsoJwk

  @jwks_relative_path "/.well-known/jwks.json"

  def launch(
        conn,
        %{
          "product_id" => product_id,
          "cognito_id_token" => jwt,
          "error_url" => _error_url,
          "community_id" => community_id
        } = params
      ) do
    with {:ok, jwk} <- get_jwk(jwt),
         {true, %{fields: jwt_fields}, _} <- JOSE.JWT.verify_strict(jwk, ["RS256"], jwt),
         {:ok, user} <- create_lms_user(jwt_fields),
         {:ok, _account} <- create_community_account(user.id, community_id) do
      conn
      |> use_pow_config(:user)
      |> Pow.Plug.create(user)
      |> redirect(to: Routes.page_delivery_path(conn, :index, product_id))
    else
      {false, _, _} ->
        redirect_with_error(conn, params, "Unable to verify credentials")

      {:error, error} ->
        redirect_with_error(conn, params, snake_case_to_friendly(error))

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, params, "Invalid parameters")
    end
  end

  def launch(conn, params) do
    redirect_with_error(conn, params, "Missing parameters")
  end

  defp get_jwk(jwt) do
    with {:ok, %{"kid" => kid}} <- Joken.peek_header(jwt),
         {:ok, %{"iss" => issuer}} <- Joken.peek_claims(jwt),
         {:ok, sso_jwk} <- find_or_fetch_jwt(kid, issuer) do
      {:ok, JOSE.JWK.from_pem(sso_jwk.pem)}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  def find_or_fetch_jwt(kid, issuer) do
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

  def persist_keys(%JOSE.JWK{keys: {_, keys}}, kid) do
    key =
      keys
      |> Enum.map(&Institutions.build_jwk/1)
      |> Institutions.insert_bulk_jwks()
      |> Enum.find(fn %SsoJwk{kid: jwk_kid} -> jwk_kid == kid end)

    if key, do: {:ok, key}, else: {:error, "Missing Key"}
  end

  def persist_keys(_, _), do: {:error, "Error retrieving the JWKS"}

  defp get_error_url(%{"error_url" => error_url}), do: error_url
  defp get_error_url(_params), do: "/unauthorized"

  defp redirect_with_error(conn, params, error) do
    error_url = get_error_url(params)

    conn
    |> redirect(external: "#{error_url}?error=#{error}")
    |> halt()
  end

  defp create_lms_user(fields) do
    Accounts.insert_or_update_lms_user(%{
      sub: Map.get(fields, "sub"),
      preferred_username: Map.get(fields, "cognito:username"),
      email: Map.get(fields, "email"),
      can_create_sections: true
    })
  end

  defp create_community_account(user_id, community_id) do
    Groups.create_community_account(%{user_id: user_id, community_id: community_id})
  end
end
