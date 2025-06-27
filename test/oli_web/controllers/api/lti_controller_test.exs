defmodule OliWeb.Api.LtiControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Mox

  setup :verify_on_exit!

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Delivery.Sections
  alias Oli.Test.MockHTTP

  defp accept_json(%{conn: conn}) do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup [:accept_json]

  describe "authoring launch_details" do
    setup [:setup_project]

    test "returns LTI launch details", %{conn: conn, project: project, activity_id: activity_id} do
      conn = get(conn, ~p"/api/v1/lti/projects/#{project.slug}/launch_details/#{activity_id}")
      assert json_response(conn, 200)["name"] == "some name"

      assert json_response(conn, 200)["launch_params"]["iss"] == Oli.Utils.get_base_url()
      assert json_response(conn, 200)["launch_params"]["client_id"] == "some client_id"

      assert json_response(conn, 200)["launch_params"]["target_link_uri"] ==
               "some target_link_uri"

      assert json_response(conn, 200)["launch_params"]["login_url"] == "some login_url"
      assert json_response(conn, 200)["launch_params"]["login_hint"] != nil
      assert json_response(conn, 200)["launch_params"]["status"] != nil
    end
  end

  describe "delivery launch_details" do
    setup [:setup_section]

    test "returns LTI launch details", %{conn: conn, section: section, activity_id: activity_id} do
      conn = get(conn, ~p"/api/v1/lti/sections/#{section.slug}/launch_details/#{activity_id}")
      assert json_response(conn, 200)["name"] == "some name"

      assert json_response(conn, 200)["launch_params"]["iss"] == Oli.Utils.get_base_url()
      assert json_response(conn, 200)["launch_params"]["client_id"] == "some client_id"

      assert json_response(conn, 200)["launch_params"]["target_link_uri"] ==
               "some target_link_uri"

      assert json_response(conn, 200)["launch_params"]["login_url"] == "some login_url"
      assert json_response(conn, 200)["launch_params"]["login_hint"] != nil
      assert json_response(conn, 200)["launch_params"]["status"] != nil
    end
  end

  describe "auth_token" do
    setup [:accept_json]

    defp generate_client_assertion(client_id, key, kid) do
      now = DateTime.utc_now() |> DateTime.to_unix()

      claims = %{
        "iss" => client_id,
        "sub" => client_id,
        "aud" => client_id,
        "iat" => now,
        "exp" => now + 3600,
        "jti" => UUID.uuid4()
      }

      jwk = JOSE.JWK.from_pem(key)

      {_, jwt} =
        JOSE.JWT.sign(
          jwk,
          %{"alg" => "RS256", "kid" => kid},
          claims
        )
        |> JOSE.JWS.compact()

      jwt
    end

    test "returns access token for valid client_assertion", %{conn: conn} do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      # Insert a platform instance using Oli.Factory
      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      # Expect HTTP request to fetch the keyset using Mox
      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      client_assertion = generate_client_assertion(client_id, key_pem, "test-kid")

      params = %{
        "grant_type" => "client_credentials",
        "client_assertion" => client_assertion,
        "scope" =>
          "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly https://purl.imsglobal.org/spec/lti-ags/scope/score"
      }

      conn = post(conn, ~p"/lti/auth/token", params)
      resp = json_response(conn, 200)
      assert resp["access_token"]
      assert resp["token_type"] == "bearer"
      assert resp["expires_in"] == 3600

      assert resp["scope"] ==
               "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly https://purl.imsglobal.org/spec/lti-ags/scope/score"
    end

    @tag capture_log: true
    test "returns 401 for invalid client_assertion", %{conn: conn} do
      params = %{
        "grant_type" => "client_credentials",
        "client_assertion" => "invalid.jwt.token",
        "scope" => "scope1"
      }

      conn = post(conn, ~p"/lti/auth/token", params)
      assert json_response(conn, 401)["error"] == "invalid_request"
    end

    test "returns 400 for missing params", %{conn: conn} do
      conn = post(conn, ~p"/lti/auth/token", %{})
      assert json_response(conn, 400)["error"] == "invalid_request"
    end
  end

  defp create_lti_external_tool_activity() do
    attrs = %{
      "client_id" => "some client_id",
      "custom_params" => "some custom_params",
      "description" => "some description",
      "keyset_url" => "some keyset_url",
      "login_url" => "some login_url",
      "name" => "some name",
      "redirect_uris" => "some redirect_uris",
      "target_link_uri" => "some target_link_uri"
    }

    PlatformExternalTools.register_lti_external_tool_activity(attrs)
  end

  def setup_section(%{conn: conn}) do
    {:ok, seeds} = setup_project(%{conn: conn})

    {:ok, pub1} = Publishing.publish_project(seeds.project, "some changes", seeds.author.id)

    {:ok, section} =
      Sections.create_section(%{
        title: "3",
        registration_open: true,
        open_and_free: true,
        context_id: UUID.uuid4(),
        institution_id: seeds.institution.id,
        base_project_id: seeds.project.id,
        analytics_version: :v1
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub1)

    student = user_fixture(%{independent_learner: false})

    Sections.enroll(student.id, section.id, [
      Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
    ])

    conn =
      log_in_user(
        conn,
        student
      )

    {:ok,
     Map.merge(seeds, %{
       conn: conn,
       section: section,
       student: student
     })}
  end

  def setup_project(%{conn: conn}) do
    {:ok, {_platform_instance, activity_registration, _deployment}} =
      create_lti_external_tool_activity()

    seeds = Oli.Seeder.base_project_with_resource2()

    project = Map.get(seeds, :project)
    revision = Map.get(seeds, :revision1)
    author = Map.get(seeds, :author)

    content = %{
      "openInNewTab" => "true",
      "authoring" => %{
        "parts" => []
      }
    }

    {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    {:ok, {%{slug: slug2, resource_id: activity_id2}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    seeds = Map.put(seeds, :activity_id, activity_id) |> Map.put(:activity_id2, activity_id2)

    update = %{
      "content" => %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "activity-reference",
            "id" => "1",
            "activitySlug" => slug
          },
          %{
            "type" => "activity-reference",
            "id" => "2",
            "activitySlug" => slug2
          }
        ]
      }
    }

    PageEditor.acquire_lock(project.slug, revision.slug, author.email)
    assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

    conn =
      log_in_author(
        conn,
        seeds.author
      )

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
