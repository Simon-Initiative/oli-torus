defmodule OliWeb.CognitoControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Mox

  alias Oli.{Accounts, Groups}
  alias Oli.Delivery.Sections

  describe "launch" do
    setup do
      community = insert(:community, name: "Infiniscope")
      section = insert(:section, %{slug: "open_section", open_and_free: true})
      email = build(:user).email

      [community: community, section: section, email: email]
    end

    test "prompts a user with no enrollments to create section from product", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/sections/independent/new?source_id=product%3A#{section.id}\">redirected</a>.</body></html>"

      new_user = Accounts.get_user_by(%{email: email})

      assert new_user
      assert new_user.can_create_sections
      assert Groups.get_community_account_by!(%{user_id: new_user.id, community_id: community.id})
    end

    test "prompts a user with no enrollments to create section from project", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", section.base_project.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/sections/independent/new?source_id=project%3A#{section.base_project.id}\">redirected</a>.</body></html>"

      new_user = Accounts.get_user_by(%{email: email})

      assert new_user
      assert new_user.can_create_sections
      assert Groups.get_community_account_by!(%{user_id: new_user.id, community_id: community.id})
    end

    test "redirects user with enrollments to my courses from product", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {:ok, user} =
        Accounts.insert_or_update_lms_user(%{
          sub: "user999",
          preferred_username: "user999",
          email: email,
          can_create_sections: true
        })

      Sections.enroll(user.id, section.id, [])

      insert(:community_user_account, user: user, community: community)

      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/sections\">redirected</a>.</body></html>"
    end

    test "redirects user with enrollments to my courses from project", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {:ok, user} =
        Accounts.insert_or_update_lms_user(%{
          sub: "user999",
          preferred_username: "user999",
          email: email,
          can_create_sections: true
        })

      Sections.enroll(user.id, section.id, [])

      insert(:community_user_account, user: user, community: community)

      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project", section.base_project.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/sections\">redirected</a>.</body></html>"
    end

    test "redirects to provided error_url with error message", %{
      conn: conn,
      community: community,
      section: section
    } do
      params =
        community.id
        |> valid_params("12")
        |> Map.put("product_slug", section.slug)
        |> Map.delete("cognito_id_token")

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Missing parameters\">redirected</a>.</body></html>"
    end

    test "redirects to unauthorized url with bad product slug", %{
      conn: conn,
      community: community,
      section: _section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", "bad")

      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      assert conn
             |> get(Routes.cognito_path(conn, :launch, "bad", params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Invalid product or project\">redirected</a>.</body></html>"
    end

    test "redirects to unauthorized url with bad project slug", %{
      conn: conn,
      community: community,
      section: _section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", "bad")

      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      assert conn
             |> get(Routes.cognito_path(conn, :launch, "bad", params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Invalid product or project\">redirected</a>.</body></html>"
    end

    test "redirects to unauthorized url with missing error url", %{
      conn: conn,
      community: community,
      section: section
    } do
      params =
        community.id
        |> valid_params("12")
        |> Map.put("product_slug", "bad")
        |> Map.delete("error_url")

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/unauthorized?error=Missing parameters\">redirected</a>.</body></html>"
    end

    test "does not create user when the cognito_id_token is malformed", %{
      conn: conn,
      community: community,
      section: section
    } do
      params =
        community.id
        |> valid_params("bad_token")
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Token Malformed\">redirected</a>.</body></html>"
    end

    test "does not create user when the JWKS endpoint is not working", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :error))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Error retrieving the jwks\">redirected</a>.</body></html>"
    end

    test "does not create user when it fails to verify the id token", %{
      conn: conn,
      community: community,
      section: section,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email, "RS384")
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Unable to verify credentials\">redirected</a>.</body></html>"
    end

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
      signer = Joken.Signer.create(alg, %{"pem" => jwk.pem}, %{"kid" => jwk.kid})
      claims = build_claims(email)

      {:ok, claims} =
        Joken.Config.default_claims()
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      {id_token, jwk, claims["iss"]}
    end

    defp build_claims(email) do
      %{
        "at_hash" => UUID.uuid4(),
        "sub" => "user999",
        "email_verified" => true,
        "iss" => "issuer",
        "cognito:username" => "user999",
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

    defp valid_params(community_id, id_token) do
      %{
        "community_id" => community_id,
        "cognito_id_token" => id_token,
        "error_url" => "https://www.example.com/lesson/34"
      }
    end
  end
end
