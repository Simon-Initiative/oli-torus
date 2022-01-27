defmodule OliWeb.CognitoControllerTest do
  use OliWeb.ConnCase

  import ExUnit.CaptureLog
  import Oli.Factory
  import Mox

  alias Oli.Accounts
  alias Oli.Groups
  alias Oli.Groups.Community
  alias Oli.Delivery.Sections.Section

  @error_url "https://www.example.com"

  describe "launch" do
    setup do
      community = insert(:community, name: "Infiniscope")
      section = insert(:section, %{slug: "open_section", open_and_free: true})
      email = build(:user).email

      [community: community, section: section, email: email]
    end

    test "creates user and adds him as community member", %{
      conn: conn,
      community: %Community{id: community_id},
      section: %Section{slug: slug},
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_params(community_id, id_token, slug)

      body =
        conn
        |> get(cognito_launch_path(conn, params))
        |> html_response(302)

      assert body =~ "You are being <a href=\"/sections/#{slug}/overview\">redirected</a>"

      new_user = Accounts.get_user_by(%{email: email})

      assert new_user
      assert new_user.can_create_sections
      assert Groups.get_community_account_by!(%{user_id: new_user.id, community_id: community_id})
    end

    test "does not create user when there is a missing param", %{
      conn: conn,
      section: %Section{slug: slug},
      email: email
    } do
      params = %{
        community_id: "some_id",
        course_section_id: slug,
        error_url: @error_url
      }

      error_message = "Id Token - missing or invalid params"

      assert capture_log(fn ->
               body =
                 conn
                 |> get(cognito_launch_path(conn, params))
                 |> html_response(302)

               assert body =~
                        "You are being <a href=\"#{@error_url}?error=#{error_message}\">redirected</a>"

               refute Accounts.get_user_by(%{email: email})
             end) =~ error_message
    end

    test "does not create user when the id token is malformed", %{
      conn: conn,
      section: %Section{slug: slug},
      email: email
    } do
      params = valid_params("some id", "bad_token", slug)

      error_message = "Token Malformed"

      assert capture_log(fn ->
               body =
                 conn
                 |> get(cognito_launch_path(conn, params))
                 |> html_response(302)

               assert body =~
                        "You are being <a href=\"#{@error_url}?error=#{error_message}\">redirected</a>"

               refute Accounts.get_user_by(%{email: email})
             end) =~ error_message
    end

    test "does not create user when the JWKS endpoint is not working", %{
      conn: conn,
      community: %Community{id: community_id},
      section: %Section{slug: slug},
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :error))

      params = valid_params(community_id, id_token, slug)
      error_message = "Error retrieving the jwks - jwks not present"

      assert capture_log(fn ->
               body =
                 conn
                 |> get(cognito_launch_path(conn, params))
                 |> html_response(302)

               assert body =~
                        "You are being <a href=\"#{@error_url}?error=#{error_message}\">redirected</a>"

               refute Accounts.get_user_by(%{email: email})
             end) =~ error_message
    end

    test "does not create user when it fails to verify the id token", %{
      conn: conn,
      community: %Community{id: community_id},
      section: %Section{slug: slug},
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email, "RS384")
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_params(community_id, id_token, slug)
      error_message = "Unable to verify credentials"

      assert capture_log(fn ->
               body =
                 conn
                 |> get(cognito_launch_path(conn, params))
                 |> html_response(302)

               assert body =~
                        "You are being <a href=\"#{@error_url}?error=#{error_message}\">redirected</a>"

               refute Accounts.get_user_by(%{email: email})
             end) =~ error_message
    end

    test "does not create user when the id token is corrupted", %{
      conn: conn,
      community: %Community{id: community_id},
      section: %Section{slug: slug},
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      # corrupt id token
      corruputed_token =
        id_token
        |> String.split(".")
        |> (fn [header | payload_and_key] -> [String.slice(header, 0..-2) | payload_and_key] end).()
        |> Enum.join(".")

      params = valid_params(community_id, corruputed_token, slug)

      error_message = "Unknown error occurred - Elixir.Jason.DecodeError"

      assert capture_log(fn ->
               body =
                 conn
                 |> get(cognito_launch_path(conn, params))
                 |> html_response(302)

               assert body =~
                        "You are being <a href=\"#{@error_url}?error=#{error_message}\">redirected</a>"

               refute Accounts.get_user_by(%{email: email})
             end) =~ error_message
    end

    defp cognito_launch_path(conn, params), do: Routes.cognito_path(conn, :launch, params)

    defp mock_jwks_endpoint(url, jwk, :ok) do
      fn ^url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               keys: [
                 jwk.pem
                 |> JOSE.JWK.from_pem()
                 |> JOSE.JWK.to_public()
                 |> JOSE.JWK.to_map()
                 |> (fn {_kty, public_jwk} -> public_jwk end).()
                 |> Map.put("typ", jwk.typ)
                 |> Map.put("alg", jwk.alg)
                 |> Map.put("kid", jwk.kid)
                 |> Map.put("use", "sig")
               ]
             })
         }}
      end
    end

    defp mock_jwks_endpoint(url, _jwk, :error) do
      fn ^url ->
        {:ok, %HTTPoison.Response{status_code: 404, body: "jwks not present"}}
      end
    end

    defp generate_token(email, alg \\ "RS256") do
      jwk = build(:sso_jwk, alg: alg)

      custom_header = %{"kid" => jwk.kid}
      signer = Joken.Signer.create(alg, %{"pem" => jwk.pem}, custom_header)

      claims = build_claims(email)
      issuer = claims["iss"]

      {:ok, claims} =
        Joken.Config.default_claims()
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      {id_token, jwk, issuer}
    end

    defp build_claims(email) do
      sub = UUID.uuid4()

      %{
        "at_hash" => UUID.uuid4(),
        "sub" => sub,
        "email_verified" => true,
        "iss" => "issuer",
        "cognito:username" => sub,
        "origin_jti" => UUID.uuid4(),
        "aud" => UUID.uuid4(),
        "event_id" => UUID.uuid4(),
        "token_use" => "id",
        "auth_time" => 1_642_608_077,
        "exp" => 1_642_611_677,
        "iat" => 1_642_608_077,
        "jti" => UUID.uuid4(),
        "email" => email
      }
    end

    defp valid_params(community_id, id_token, section_slug) do
      %{
        "community_id" => community_id,
        "course_section_id" => section_slug,
        "id_token" => id_token,
        "error_url" => @error_url
      }
    end
  end
end
