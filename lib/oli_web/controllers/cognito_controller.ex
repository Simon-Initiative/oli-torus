defmodule OliWeb.CognitoController do
  use OliWeb, :controller
  import Oli.HTTP
  import Oli.Utils
  import Ecto
  import Ecto.Changeset
  require Logger

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Groups.CommunityAccount
  alias Oli.Institutions.SsoJwks

  def launch(conn, params) do
    try do
      with {:ok, valid_params} <- validate_query_params(params) do
        jwk = get_jwk(Map.get(params, "id_token"))
        jwk_from_pem = JOSE.JWK.from_pem(jwk.pem)
        case JOSE.JWT.verify_strict(jwk_from_pem, ["RS256"], valid_params.id_token) do
          {true, verified_jwt, _} ->
            case Accounts.insert_or_update_lms_user(%{
                  sub: Map.get(verified_jwt.fields, "sub"),
                  preferred_username: Map.get(verified_jwt.fields, "cognito:username"),
                  email: Map.get(verified_jwt.fields, "email"),
                  can_create_sections: true
                }) do
              {:ok, user} ->
                  attrs = %{user_id: user.id, community_id: valid_params.community_id}

                  %CommunityAccount{}
                  |> CommunityAccount.changeset(attrs)
                  |> Repo.insert()

                  conn
                  |> use_pow_config(:user)
                  |> Pow.Plug.create(user)
                  |> redirect(to: Routes.page_delivery_path(conn, :index, valid_params.course_section_id))
            end

          {false, _, _} ->
            error_url = get_error_url(conn, valid_params)
            conn
            |> redirect(external: "#{error_url}?error=Unable to verify credentials")
            |> halt()
        end
      else
        {:error, changeset} ->
          error_fields = changeset.errors
          |> Keyword.keys()
          |> Enum.join(", ")

          error_url = get_error_url(conn, changeset.changes)
          conn
          |> redirect(external: "#{error_url}?error=#{error_fields} - missing or invalid")
          |> halt()
      end
    rescue
      e ->
        uuid = Ecto.UUID.generate
        Logger.error("#{uuid} - #{inspect(e)}")

        error_url = get_error_url(conn, %{})
        conn
        |> redirect(external: "#{error_url}?error=Unknown error occurred - #{uuid}")
    end
  end

  def get_jwk(id_token) do
    jwt_header = id_token
    |> Joken.peek_header()

    io("jwt_header", jwt_header)

    jwt_payload = id_token
    |> JOSE.JWT.peek_payload()
    io("jwt_payload", jwt_payload)

    issuer = Map.get(jwt_payload.fields, "iss")

    case Joken.peek_header(id_token) do
      {:ok, result} ->
        case Repo.get_by(SsoJwks, kid: Map.get(result, "kid")) do
          nil ->
            jwks = get_cognito_jwks(issuer)
            io("jwks from cognito", jwks)

            sso_jwks = Enum.map(elem(jwks.keys, 1), fn(s) -> get_sso_jwks(s) end)

            Enum.each(sso_jwks, fn(attrs) ->
              %SsoJwks{}
              |> SsoJwks.changeset(attrs)
              |> Repo.insert()
            end)

            case Repo.get_by(SsoJwks, kid: Map.get(result, "kid")) do
              jwk -> jwk
            end

          jwk ->
            jwk
        end
    end
  end

  def get_sso_jwks(item) do
    pem = JOSE.JWK.to_pem(item)

    sso_jwks = Map.put(%{typ: "JWT"}, :alg, Map.get(elem(item, 3), "alg"))
    |> Map.put(:kid, Map.get(elem(item, 3), "kid"))
    |> Map.put(:pem, elem(pem, 1))

    sso_jwks
  end

  def get_cognito_jwks(issuer) do
    url = "#{issuer}/.well-known/jwks.json"
    case http().get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Poison.decode!
        |> JOSE.JWK.from_map
    end
  end

  def get_error_url(conn, params) do
    case Map.fetch(params, :error_url) do
      {:ok, error_url} ->
        error_url
      :error ->
        "/unauthorized"
    end
  end

  def validate_query_params(params) do
    data = %{}

    types = %{
      course_section_id: :string,
      community_id: :integer,
      id_token: :string,
      error_url: :string
    }

    changeset =
      {data, types}
      |> cast(params, Map.keys(types))
      |> validate_required([:course_section_id, :community_id, :id_token, :error_url])

    if changeset.valid? do
        {:ok, apply_changes(changeset)}
    else
        {:error, changeset}
    end
  end
end
