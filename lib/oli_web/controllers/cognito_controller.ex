defmodule OliWeb.CognitoController do
  use OliWeb, :controller
  import Oli.HTTP
  import Oli.Utils
  import Ecto.Changeset
  require Logger

  alias Oli.Accounts
  alias Oli.Groups
  alias Oli.Institutions
  alias Oli.Institutions.SsoJwk

  @jwks_relative_path "/.well-known/jwks.json"

  def launch(conn, params) do
    try do
      with {:ok, valid_params} <- validate_query_params(params),
           {:ok, %SsoJwk{pem: pem}} <- get_jwk(valid_params.id_token) do
        jwk = JOSE.JWK.from_pem(pem)

        case JOSE.JWT.verify_strict(jwk, ["RS256"], valid_params.id_token) do
          {true, %{fields: jwt_fields}, _} ->
            case Accounts.insert_or_update_lms_user(%{
                   sub: Map.get(jwt_fields, "sub"),
                   preferred_username: Map.get(jwt_fields, "cognito:username"),
                   email: Map.get(jwt_fields, "email"),
                   can_create_sections: true
                 }) do
              {:ok, user} ->
                community_id = valid_params.community_id

                Groups.create_community_account(%{user_id: user.id, community_id: community_id})

                conn
                |> use_pow_config(:user)
                |> Pow.Plug.create(user)
                |> redirect(
                  to: Routes.page_delivery_path(conn, :index, valid_params.course_section_id)
                )

              {:error, %Ecto.Changeset{errors: errors}} ->
                error_fields =
                  errors
                  |> Keyword.keys()
                  |> Enum.join(", ")

                error_message = error_fields <> " - missing or invalid"
                Logger.error(error_message)

                redirect_with_error(conn, valid_params, error_message)
            end

          {false, _, _} ->
            error_message = "Unable to verify credentials"
            Logger.error(error_message)

            redirect_with_error(conn, valid_params, error_message)
        end
      else
        {:error, error} ->
          error_message = snake_case_to_friendly(error)

          Logger.error(error_message)

          redirect_with_error(conn, params, error_message)
      end
    rescue
      e ->
        %exception_type{} = e
        error_message = "Unknown error occurred - #{exception_type}"
        Logger.error("#{uuid()} - #{error_message}")

        redirect_with_error(conn, params, error_message)
    end
  end

  defp validate_query_params(params) do
    data = %{}

    types = %{
      course_section_id: :string,
      id_token: :string,
      error_url: :string,
      community_id: :string
    }

    changeset =
      {data, types}
      |> cast(params, Map.keys(types))
      |> validate_required([:course_section_id, :id_token, :error_url, :community_id])

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      error_fields =
        changeset.errors
        |> Keyword.keys()
        |> Enum.join(", ")

      error_message = error_fields <> " - missing or invalid params"

      {:error, error_message}
    end
  end

  defp get_cognito_jwks(issuer) do
    url = issuer <> @jwks_relative_path

    case http().get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        jwks =
          body
          |> Poison.decode!()
          |> JOSE.JWK.from_map()

        {:ok, jwks}

      {:ok, %HTTPoison.Response{body: body}} ->
        {:error, "Error retrieving the JWKS - #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Error retrieving the JWKS - #{reason}"}
    end
  end

  defp get_jwk(id_token) do
    with {:ok, %{"kid" => kid}} <- Joken.peek_header(id_token),
         {:ok, %{"iss" => issuer}} <- Joken.peek_claims(id_token),
         nil <- Institutions.get_jwk_by(%{kid: kid}),
         {:ok, %JOSE.JWK{keys: {_, keys}}} <- get_cognito_jwks(issuer) do
      jwk =
        keys
        |> Enum.map(&Institutions.build_jwk/1)
        |> Institutions.insert_bulk_jwks()
        |> Enum.find(fn %SsoJwk{kid: jwk_kid} -> jwk_kid == kid end)

      {:ok, jwk}
    else
      {:error, error} ->
        {:error, error}

      %SsoJwk{} = jwk ->
        {:ok, jwk}
    end
  end

  defp get_error_url(%{"error_url" => error_url}), do: error_url
  defp get_error_url(%{error_url: error_url}), do: error_url
  defp get_error_url(_params), do: "/unauthorized"

  defp redirect_with_error(conn, params, error) do
    error_url = get_error_url(params)

    conn
    |> redirect(external: "#{error_url}?error=#{error}")
    |> halt()
  end
end
