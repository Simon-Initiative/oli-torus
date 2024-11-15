defmodule OliWeb.CognitoControllerTest do
  use OliWeb.ConnCase
  import Swoosh.TestAssertions

  import Oli.Factory
  import Mox

  alias Oli.{Accounts, Groups}
  alias Oli.Authoring.{Clone, Course}
  alias Oli.Delivery.Sections

  setup do
    community = insert(:community, name: "Infiniscope")
    section = insert(:section, %{slug: "open_section", open_and_free: true})
    email = build(:user).email
    author = author_fixture(%{system_role_id: Accounts.SystemRole.role_id().system_admin})
    project = insert(:project, allow_duplication: true)
    resource = insert(:resource)
    revision = insert(:revision, resource: resource)

    publication =
      insert(:publication, project: project, root_resource_id: resource.id, published: nil)

    insert(:published_resource, publication: publication, resource: resource, revision: revision)

    [community: community, section: section, email: email, author: author, project: project]
  end

  import Phoenix.LiveViewTest

  describe "index" do
    test "redirects user to my courses", %{
      conn: conn,
      community: community,
      email: email
    } do
      {:ok, _user} =
        Accounts.insert_or_update_sso_user(%{
          sub: "user999",
          preferred_username: "user999",
          email: email,
          can_create_sections: true
        })

      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_index_params(community.id, id_token)

      assert conn
             |> get(Routes.cognito_path(conn, :index, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/workspaces/instructor\">redirected</a>.</body></html>"
    end

    test "preserve existing linked author account", %{
      conn: conn,
      community: community,
      email: email
    } do
      author_email = "author@email.com"

      author = author_fixture(%{email: author_email})

      {:ok, _user} =
        Accounts.insert_or_update_sso_user(%{
          sub: "user999",
          preferred_username: "user999",
          email: email,
          can_create_sections: true,
          author_id: author.id
        })

      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_index_params(community.id, id_token)

      conn = get(conn, ~p"/cognito/launch?#{params}")

      {:ok, view, _html} = live(recycle(conn), ~p"/workspaces/instructor")

      assert view
             |> element(
               ~s(#workspace-user-menu-dropdown div[role="linked authoring account email"])
             )
             |> render() =~ author_email

      # SSO user is logged into the course_author workspace automatically
      {:ok, view, _html} = live(recycle(conn), ~p"/workspaces/course_author")

      assert view |> has_element?(~s(#button-new-project), "New Project")
    end

    test "create and linked an author account", %{
      conn: conn,
      community: community,
      email: email
    } do
      {:ok, user} =
        Accounts.insert_or_update_sso_user(%{
          sub: "user999",
          preferred_username: "user999",
          email: email,
          can_create_sections: true
        })

      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_index_params(community.id, id_token)

      conn = get(conn, ~p"/cognito/launch?#{params}")

      {:ok, view, _html} = live(recycle(conn), ~p"/workspaces/instructor")

      assert view
             |> element(
               ~s(#workspace-user-menu-dropdown div[role="linked authoring account email"])
             )
             |> render() =~ user.email
    end

    test "data is correctly taken when creating an author account", %{
      conn: conn,
      community: community,
      email: email,
      author: author
    } do
      {id_token, jwk, issuer} = generate_token(email)

      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params = valid_index_params(community.id, id_token)

      conn = get(conn, ~p"/cognito/launch?#{params}")

      conn =
        recycle(conn)
        |> log_in_author(author)

      new_author = Accounts.get_author_by_email(email)
      new_user = Accounts.get_user_by(%{email: email})

      {:ok, view, _html} = live(conn, ~p"/admin/authors/#{new_author.id}")

      assert view |> element("input[value=\"#{new_author.name}\"]") |> render() =~ new_author.name
      assert view |> element("input[id=\"email\"]") |> render() =~ new_author.email

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{new_user.id}")

      assert view |> element("input[value=\"#{new_user.name}\"]") |> render() =~ new_user.name
      assert view |> element("input[id=\"user_email\"]") |> render() =~ new_user.email
    end

    test "redirects to provided error_url with missing params", %{
      conn: conn,
      community: community
    } do
      params =
        community.id
        |> valid_index_params("12")
        |> Map.delete("id_token")

      assert conn
             |> get(Routes.cognito_path(conn, :index, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Missing id token\">redirected</a>.</body></html>"
    end

    test "does not create user when the id_token is malformed", %{
      conn: conn,
      community: community
    } do
      params = valid_index_params(community.id, "bad_token")

      assert conn
             |> get(Routes.cognito_path(conn, :index, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Token Malformed\">redirected</a>.</body></html>"
    end

    test "does not create user when the JWKS endpoint is not working", %{
      conn: conn,
      community: community,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :error))

      params =
        community.id
        |> valid_index_params(id_token)

      assert conn
             |> get(Routes.cognito_path(conn, :index, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Error retrieving the jwks\">redirected</a>.</body></html>"
    end

    test "does not create user when it fails to verify the id token", %{
      conn: conn,
      community: community,
      email: email
    } do
      {id_token, jwk, issuer} = generate_token(email, "RS384")
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_index_params(id_token)

      assert conn
             |> get(Routes.cognito_path(conn, :index, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Unable to verify credentials\">redirected</a>.</body></html>"
    end
  end

  describe "launch" do
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

    test "redirects user with enrollments to an intermediate page to prompt if they really want to create another section from product",
         %{
           conn: conn,
           community: community,
           section: section,
           email: email
         } do
      {:ok, user} =
        Accounts.insert_or_update_sso_user(%{
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
               "<html><body>You are being <a href=\"/cognito/prompt_create/products/#{section.slug}\">redirected</a>.</body></html>"
    end

    test "redirects user with enrollments to an intermediate page to prompt if they really want to create another section from project",
         %{
           conn: conn,
           community: community,
           section: section,
           email: email
         } do
      {:ok, user} =
        Accounts.insert_or_update_sso_user(%{
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
        |> Map.put("project_slug", section.base_project.slug)

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/cognito/prompt_create/projects/#{section.base_project.slug}\">redirected</a>.</body></html>"
    end

    test "redirects to provided error_url with missing params", %{
      conn: conn,
      community: community,
      section: section
    } do
      params =
        community.id
        |> valid_params("12")
        |> Map.put("product_slug", section.slug)
        |> Map.delete("id_token")

      assert conn
             |> get(Routes.cognito_path(conn, :launch, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Missing id token\">redirected</a>.</body></html>"
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

    test "redirects to unauthorized url with missing error_url", %{
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
               "<html><body>You are being <a href=\"/unauthorized?error=Token Malformed\">redirected</a>.</body></html>"
    end

    test "does not create user when the id_token is malformed", %{
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
  end

  describe "launch_clone" do
    test "allows a user to clone a project they do not already have cloned",
         %{
           conn: conn,
           community: community,
           email: email,
           project: project
         } do
      {id_token, jwk, issuer} = generate_token(email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", project.slug)

      assert conn
             |> get(Routes.project_clone_path(conn, :launch_clone, project.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/workspaces/course_author"

      # creates new author and links it with user
      author = Accounts.get_author_by_email(email)
      assert author
      assert author.id == Accounts.get_user_by(%{email: email}).author_id

      assert length(Clone.existing_clones(project.slug, author)) == 1
    end

    test "properly redirects to an intermediate page to prompt if they really want to clone again",
         %{
           conn: conn,
           community: community,
           author: author,
           project: project
         } do
      {id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      Clone.clone_project(project.slug, author)

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", project.slug)

      assert conn
             |> get(Routes.project_clone_path(conn, :launch_clone, project.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/cognito/prompt_clone/projects/" <>
                 project.slug
    end

    test "forbids a user with an authoring account to clone a project that does not allow duplication",
         %{
           conn: conn,
           community: community,
           author: author,
           project: project
         } do
      {id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", project.slug)

      Course.update_project(project, %{allow_duplication: false})

      assert conn
             |> get(Routes.project_clone_path(conn, :launch_clone, project.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=This project does not allow duplication"
    end

    test "forbids a user with an authoring account to clone a product",
         %{
           conn: conn,
           community: community,
           author: author,
           section: section
         } do
      {id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("product_slug", section.slug)

      assert conn
             |> get(Routes.product_clone_path(conn, :launch_clone, section.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=This is not supported"
    end

    test "fails if the project does not exist given the supplied slug",
         %{
           conn: conn,
           community: community,
           author: author
         } do
      {id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", "this_project_slug_does_not_exist")

      assert conn
             |> get(
               Routes.product_clone_path(
                 conn,
                 :launch_clone,
                 "this_project_slug_does_not_exist",
                 params
               )
             )
             |> html_response(302) =~
               "<html><body>You are being <a href=\"https://www.example.com/lesson/34?error=Invalid product or project"
    end

    test "fails if there are missing parameters",
         %{
           conn: conn,
           community: community,
           author: author,
           project: project
         } do
      {id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      params =
        community.id
        |> valid_params(id_token)
        |> Map.put("project_slug", project.slug)
        |> Map.delete("error_url")

      assert conn
             |> get(Routes.product_clone_path(conn, :launch_clone, project.slug, params))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/unauthorized?error=Missing parameters"
    end
  end

  describe "clone" do
    setup [:admin_conn]

    test "allows a user to clone a project when it allows duplication",
         %{
           conn: conn,
           project: project
         } do
      assert conn
             |> get(Routes.cognito_path(conn, :clone, project.slug))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/workspaces/course_author"
    end

    test "fails if the project does not allow duplication",
         %{
           conn: conn,
           project: project
         } do
      Course.update_project(project, %{allow_duplication: false})

      assert conn
             |> get(Routes.cognito_path(conn, :clone, project.slug))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/unauthorized?error=This project does not allow duplication"
    end

    test "fails if the project does not exist given the supplied slug",
         %{
           conn: conn,
           author: author
         } do
      {_id_token, jwk, issuer} = generate_token(author.email)
      jwks_url = issuer <> "/.well-known/jwks.json"

      expect(Oli.Test.MockHTTP, :get, 2, mock_jwks_endpoint(jwks_url, jwk, :ok))

      assert conn
             |> get(Routes.cognito_path(conn, :clone, "this_project_slug_does_not_exist"))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"/unauthorized?error=Invalid product or project"
    end
  end

  describe "prompt_clone" do
    setup [:admin_conn]

    test "allows author to select between creating a new project copy and selecting an existing one",
         %{
           conn: conn,
           project: project,
           admin: admin
         } do
      {:ok, duplicated} = Clone.clone_project(project.slug, admin)

      html =
        conn
        |> get(Routes.prompt_project_clone_path(conn, :prompt_clone, project.slug))
        |> html_response(200)

      assert html =~
               "Would you like to\n<a href=\"/cognito/clone/#{project.slug}\">create another copy</a>"

      assert html =~
               "<a href=\"/workspaces/course_author/#{duplicated.slug}/overview\">#{duplicated.title}</a>"
    end
  end

  describe "prompt_create" do
    setup [:independent_instructor_conn]

    test "allows user to select between creating a new section and seeing my courses",
         %{
           conn: conn,
           project: project
         } do
      html =
        conn
        |> get(Routes.prompt_project_create_path(conn, :prompt_create, project.slug))
        |> html_response(200)

      assert html =~
               "Would you like to\n<a href=\"/sections/independent/new?source_id=project%3A#{project.id}\">create a new section with this lesson</a>"

      assert html =~ "<a href=\"/workspaces/instructor\">go to my existing sections</a>"
    end
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
      "sub" => "user999",
      "email_verified" => true,
      "iss" => "issuer",
      "cognito:username" => "user999",
      "origin_jti" => UUID.uuid4(),
      "aud" => UUID.uuid4(),
      "event_id" => UUID.uuid4(),
      "token_use" => "id",
      "auth_time" => 1_642_608_077,
      "name" => "name_user999",
      "exp" => 1_642_611_677,
      "iat" => 1_642_608_077,
      "jti" => UUID.uuid4(),
      "email" => email
    }
  end

  defp valid_params(community_id, id_token) do
    %{
      "community_id" => community_id,
      "id_token" => id_token,
      "error_url" => "https://www.example.com/lesson/34"
    }
  end

  defp valid_index_params(community_id, id_token) do
    %{
      "community_id" => community_id,
      "id_token" => id_token,
      "error_url" => "https://www.example.com/lesson/34"
    }
  end
end
