defmodule Oli.Lti_1p3.LaunchValidationTest do
  use OliWeb.ConnCase

  alias Oli.Lti_1p3
  alias Oli.Lti_1p3.LaunchValidation
  alias Oli.Lti_1p3.KeyGenerator

  describe "launch validation" do
    setup do
      # id_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IjBpam9aS3BaV1NKUTA3YjIyZ2JkYUNEbWdsYzdCend5ZWlRTXZLOHUtR2sifQ.eyJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS9jbGFpbS9tZXNzYWdlX3R5cGUiOiJMdGlSZXNvdXJjZUxpbmtSZXF1ZXN0IiwiZ2l2ZW5fbmFtZSI6IkNoZWxzZWEiLCJmYW1pbHlfbmFtZSI6IkNvbnJveSIsIm1pZGRsZV9uYW1lIjoiUmVpY2hlbCIsInBpY3R1cmUiOiJodHRwOi8vZXhhbXBsZS5vcmcvQ2hlbHNlYS5qcGciLCJlbWFpbCI6IkNoZWxzZWEuQ29ucm95QGV4YW1wbGUub3JnIiwibmFtZSI6IkNoZWxzZWEgUmVpY2hlbCBDb25yb3kiLCJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS9jbGFpbS9yb2xlcyI6WyJodHRwOi8vcHVybC5pbXNnbG9iYWwub3JnL3ZvY2FiL2xpcy92Mi9tZW1iZXJzaGlwI0xlYXJuZXIiLCJodHRwOi8vcHVybC5pbXNnbG9iYWwub3JnL3ZvY2FiL2xpcy92Mi9pbnN0aXR1dGlvbi9wZXJzb24jU3R1ZGVudCIsImh0dHA6Ly9wdXJsLmltc2dsb2JhbC5vcmcvdm9jYWIvbGlzL3YyL21lbWJlcnNoaXAjTWVudG9yIl0sImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpL2NsYWltL3JvbGVfc2NvcGVfbWVudG9yIjpbImE2MmM1MmMwMmJhMjYyMDAzZjVlIl0sImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpL2NsYWltL3Jlc291cmNlX2xpbmsiOnsiaWQiOiIyMDA1MiIsInRpdGxlIjoiTXkgQ291cnNlIiwiZGVzY3JpcHRpb24iOiJteSBjb3Vyc2UifSwiaHR0cHM6Ly9wdXJsLmltc2dsb2JhbC5vcmcvc3BlYy9sdGkvY2xhaW0vY29udGV4dCI6eyJpZCI6IjEwMzM3IiwibGFiZWwiOiJNeSBDb3Vyc2UiLCJ0aXRsZSI6Ik15IENvdXJzZSIsInR5cGUiOlsiQ291cnNlIl19LCJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS9jbGFpbS90b29sX3BsYXRmb3JtIjp7Im5hbWUiOiJvbGktdGVzdCIsImNvbnRhY3RfZW1haWwiOiIiLCJkZXNjcmlwdGlvbiI6IiIsInVybCI6IiIsInByb2R1Y3RfZmFtaWx5X2NvZGUiOiIiLCJ2ZXJzaW9uIjoiMS4wIiwiZ3VpZCI6MTIzN30sImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpLWFncy9jbGFpbS9lbmRwb2ludCI6eyJzY29wZSI6WyJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS1hZ3Mvc2NvcGUvbGluZWl0ZW0iLCJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS1hZ3Mvc2NvcGUvcmVzdWx0LnJlYWRvbmx5IiwiaHR0cHM6Ly9wdXJsLmltc2dsb2JhbC5vcmcvc3BlYy9sdGktYWdzL3Njb3BlL3Njb3JlIl0sImxpbmVpdGVtcyI6Imh0dHBzOi8vbHRpLXJpLmltc2dsb2JhbC5vcmcvcGxhdGZvcm1zLzEyMzcvY29udGV4dHMvMTAzMzcvbGluZV9pdGVtcyJ9LCJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS1ucnBzL2NsYWltL25hbWVzcm9sZXNlcnZpY2UiOnsiY29udGV4dF9tZW1iZXJzaGlwc191cmwiOiJodHRwczovL2x0aS1yaS5pbXNnbG9iYWwub3JnL3BsYXRmb3Jtcy8xMjM3L2NvbnRleHRzLzEwMzM3L21lbWJlcnNoaXBzIiwic2VydmljZV92ZXJzaW9ucyI6WyIyLjAiXX0sImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpLWNlcy9jbGFpbS9jYWxpcGVyLWVuZHBvaW50LXNlcnZpY2UiOnsic2NvcGVzIjpbImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpLWNlcy92MXAwL3Njb3BlL3NlbmQiXSwiY2FsaXBlcl9lbmRwb2ludF91cmwiOiJodHRwczovL2x0aS1yaS5pbXNnbG9iYWwub3JnL3BsYXRmb3Jtcy8xMjM3L3NlbnNvcnMiLCJjYWxpcGVyX2ZlZGVyYXRlZF9zZXNzaW9uX2lkIjoidXJuOnV1aWQ6N2JlYzU5NTZjNTI5N2VhY2YzODIifSwiaXNzIjoiaHR0cHM6Ly9sdGktcmkuaW1zZ2xvYmFsLm9yZyIsImF1ZCI6IjEyMzQ1IiwiaWF0IjoxNTk4MzA0MDIwLCJleHAiOjE1OTgzMDQzMjAsInN1YiI6ImE3M2Q1OWFmZmM1YjJjNGNkNDkzIiwibm9uY2UiOiJkODY3OTlmNTFmZjBkOTE3OGIzOSIsImh0dHBzOi8vcHVybC5pbXNnbG9iYWwub3JnL3NwZWMvbHRpL2NsYWltL3ZlcnNpb24iOiIxLjMuMCIsImxvY2FsZSI6ImVuLVVTIiwiaHR0cHM6Ly9wdXJsLmltc2dsb2JhbC5vcmcvc3BlYy9sdGkvY2xhaW0vbGF1bmNoX3ByZXNlbnRhdGlvbiI6eyJkb2N1bWVudF90YXJnZXQiOiJpZnJhbWUiLCJoZWlnaHQiOjMyMCwid2lkdGgiOjI0MCwicmV0dXJuX3VybCI6Imh0dHBzOi8vbHRpLXJpLmltc2dsb2JhbC5vcmcvcGxhdGZvcm1zLzEyMzcvcmV0dXJucyJ9LCJodHRwczovL3d3dy5leGFtcGxlLmNvbS9leHRlbnNpb24iOnsiY29sb3IiOiJ2aW9sZXQifSwiaHR0cHM6Ly9wdXJsLmltc2dsb2JhbC5vcmcvc3BlYy9sdGkvY2xhaW0vY3VzdG9tIjp7Im15Q3VzdG9tVmFsdWUiOiIxMjMifSwiaHR0cHM6Ly9wdXJsLmltc2dsb2JhbC5vcmcvc3BlYy9sdGkvY2xhaW0vZGVwbG95bWVudF9pZCI6IjEiLCJodHRwczovL3B1cmwuaW1zZ2xvYmFsLm9yZy9zcGVjL2x0aS9jbGFpbS90YXJnZXRfbGlua191cmkiOiJodHRwczovL2x0aS1yaS5pbXNnbG9iYWwub3JnL2x0aS90b29scy8xMTkzL2xhdW5jaGVzIn0.MbiW17eQpwyJqU62fLXcjAAEE6WIr1JpFUQIGmWVEF-qVwINsuhUrvoLd8ztMzRGk4YlG16RYNGAXuUl9cF8yadpFAyIE6D8RnZHlBeQbnKF96Rrp92uCi3tLIEn3RoYaf9SMre1yikeCcGvF2wpA54or7_S5MM8boX9MK8h-ubwDuZ7cEsM5S5dHRlmQ1vXcbq5u5he-OlW6a7kZUlmUyGS3lRwPYTZK75Ed-YNEgjoOAnX1e7dUnVBjIjJk8TSKGYiASGMSuwuTeMhmVhgBpLyesK4obMStFSiLQFi5F9Lq_bPgSSibNKg5xSoBX-hY951WMrxCawbh37IXEh_iA"
      # signer = Joken.Signer.create("HS256", "my secret", %{
      #   "kid" => "0ijoZKpZWSJQ07b22gbdaCDmglc7BzwyeiQMvK8u-Gk",
      # })
      # keys = %{
      #   "kty" => "RSA",
      #   "e" => "AQAB",
      #   "n" => "4Eoi_fokQkbeZ93AmPiiGGfHszRD568Uj16AWl4VvVlMc-rjjb5Hk8ee5B3L3PvtPdOsUjvDJAIxKNy3pMHqyOXSN5VTrE3WUVb_r2V8JyCTaNbi-zSrLNSxlb9_3ldB9A6PKvVShdmiMCpRFZ182Zbu8UEBp2pBAM9D5GiVfGOgO2df56uobjKRReV5UdcJAiypnEC8vcSAJiVN_NcASf8jpaebgktp4R_60_0vAR7wjgNsTQM86O8EXrwOvCsKlV0Mso8CMiKsEx5fSNTY4ur-z_peQ_4rua_cvhIYCdtbrjtQm_aMIXaqi5Lpj-7YAde-16BFrbl5zn8H2a7fvQ",
      #   # "kid" => "0ijoZKpZWSJQ07b22gbdaCDmglc7BzwyeiQMvK8u-Gk",
      #   "alg" => "RS256",
      #   "use" => "sig"
      # }

      %{public_key: public_key, private_key: private_key, key_id: _key_id} = KeyGenerator.generate_key_pair

      signer = Joken.Signer.create("RS256", %{"pem" => private_key}, %{
        # "kid" => "0ijoZKpZWSJQ07b22gbdaCDmglc7BzwyeiQMvK8u-Gk",
        "kid" => "some_kid",
      })

      {:ok, claims} = Joken.generate_claims(%{}, %{
          "aud" => "12345",
          "email" => "Chelsea.Conroy@example.org",
          "exp" => 1598304320,
          "family_name" => "Conroy",
          "given_name" => "Chelsea",
          "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => %{
            "lineitems" => "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/line_items",
            "scope" => ["https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
             "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
             "https://purl.imsglobal.org/spec/lti-ags/scope/score"]
          },
          "https://purl.imsglobal.org/spec/lti-ces/claim/caliper-endpoint-service" => %{
            "caliper_endpoint_url" => "https://lti-ri.imsglobal.org/platforms/1237/sensors",
            "caliper_federated_session_id" => "urn:uuid:7bec5956c5297eacf382",
            "scopes" => ["https://purl.imsglobal.org/spec/lti-ces/v1p0/scope/send"]
          },
          "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice" => %{
            "context_memberships_url" => "https://lti-ri.imsglobal.org/platforms/1237/contexts/10337/memberships",
            "service_versions" => ["2.0"]
          },
          "https://purl.imsglobal.org/spec/lti/claim/context" => %{
            "id" => "10337",
            "label" => "My Course",
            "title" => "My Course",
            "type" => ["Course"]
          },
          "https://purl.imsglobal.org/spec/lti/claim/custom" => %{
            "myCustomValue" => "123"
          },
          "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => "1",
          "https://purl.imsglobal.org/spec/lti/claim/launch_presentation" => %{
            "document_target" => "iframe",
            "height" => 320,
            "return_url" => "https://lti-ri.imsglobal.org/platforms/1237/returns",
            "width" => 240
          },
          "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest",
          "https://purl.imsglobal.org/spec/lti/claim/resource_link" => %{
            "description" => "my course",
            "id" => "20052",
            "title" => "My Course"
          },
          "https://purl.imsglobal.org/spec/lti/claim/role_scope_mentor" => ["a62c52c02ba262003f5e"],
          "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
           "http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student",
           "http://purl.imsglobal.org/vocab/lis/v2/membership#Mentor"],
          "https://purl.imsglobal.org/spec/lti/claim/target_link_uri" => "https://lti-ri.imsglobal.org/lti/tools/1193/launches",
          "https://purl.imsglobal.org/spec/lti/claim/tool_platform" => %{
            "contact_email" => "",
            "description" => "",
            "guid" => 1237,
            "name" => "oli-test",
            "product_family_code" => "",
            "url" => "",
            "version" => "1.0"
          },
          "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0",
          "https://www.example.com/extension" => %{"color" => "violet"},
          "iat" => 1598304020,
          "iss" => "https://lti-ri.imsglobal.org",
          "locale" => "en-US",
          "middle_name" => "Reichel",
          "name" => "Chelsea Reichel Conroy",
          "nonce" => "d86799f51ff0d9178b39",
          "picture" => "http://example.org/Chelsea.jpg",
          "sub" => "a73d59affc5b2c4cd493"
      })
      token = Joken.generate_and_sign!(%{}, claims, signer)

      {:ok, registration} = Lti_1p3.create_new_registration(%{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        # key_set_url: "https://lti-ri.imsglobal.org/platforms/1237/platform_keys/1231.json",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        tool_private_key: "some tool_private_key",
        kid: "some_kid"
        # kid: "0ijoZKpZWSJQ07b22gbdaCDmglc7BzwyeiQMvK8u-Gk"
      })

      {:ok, _deployment} = Lti_1p3.create_new_deployment(%{
        deployment_id: "1",
        registration_id: registration.id
      })

      state = UUID.uuid4()
      conn = Plug.Test.conn(:post, "/", %{"state" => state, "id_token" => token})
        |> Plug.Test.init_test_session(%{lti1p3_state: state})

      %{conn: conn, state: state, public_key: public_key}
    end

    test "validates a launch request", %{conn: conn, public_key: public_key} do

      get_public_key = fn _registration, _kid ->
        {:ok, JOSE.JWK.from_pem(public_key)}
      end

      assert LaunchValidation.validate(conn, get_public_key) == {:ok}
    end
  end
end
