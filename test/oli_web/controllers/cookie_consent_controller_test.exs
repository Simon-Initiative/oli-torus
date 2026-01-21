defmodule OliWeb.CookieConsentControllerTest do
  use OliWeb.ConnCase

  alias Oli.Consent
  alias Oli.Consent.CookiesConsent
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Seeder
  alias Lti_1p3.Roles.ContextRoles

  describe "persist_cookies when NOT logged in" do
    test "does not persist to database and returns user not found", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.cookie_consent_path(conn, :persist_cookies),
          cookies: [
            %{
              expiresIso: "2027-04-26T18:17:21.264Z",
              name: "_cky_opt_choices",
              value:
                ~s({"necessary":true,"functionality":true,"analytics":false,"targeting":false})
            }
          ]
        )

      # Should return success but with "user not found" info
      response = json_response(conn, 200)
      assert response["result"] == "success"
      assert response["info"] == "user not found"

      # Verify NO records were created in the database
      count = Repo.aggregate(CookiesConsent, :count, :id)
      assert count == 0
    end
  end

  describe "sync cookies on login" do
    test "syncs browser cookies to database when user has no existing preferences", %{conn: conn} do
      # Create a user with password
      user = user_fixture(%{password: "valid_password123!"})

      # Verify user has no cookie preferences in DB
      assert Consent.retrieve_cookies(user.id) == []

      # Set browser cookie on conn (simulating cookie set while not logged in)
      cookie_value =
        ~s({"necessary":true,"functionality":false,"analytics":true,"targeting":false})

      conn =
        conn
        |> Plug.Test.init_test_session([])
        |> put_req_cookie("_cky_opt_choices", cookie_value)
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => "valid_password123!"
          }
        })

      # Should redirect (successful login)
      assert redirected_to(conn)

      # Verify cookie was synced to database
      cookies = Consent.retrieve_cookies(user.id)
      assert length(cookies) == 1

      cookie = hd(cookies)
      assert cookie.name == "_cky_opt_choices"
      assert cookie.value == cookie_value
    end

    test "does NOT sync browser cookies if user already has preferences in database", %{
      conn: conn
    } do
      # Create a user with password
      user = user_fixture(%{password: "valid_password123!"})

      # Pre-populate DB with existing preferences
      existing_value =
        ~s({"necessary":true,"functionality":true,"analytics":true,"targeting":true})

      Consent.insert_cookie(
        "_cky_opt_choices",
        existing_value,
        DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second),
        user.id
      )

      # Set DIFFERENT browser cookie
      browser_value =
        ~s({"necessary":true,"functionality":false,"analytics":false,"targeting":false})

      conn =
        conn
        |> Plug.Test.init_test_session([])
        |> put_req_cookie("_cky_opt_choices", browser_value)
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => "valid_password123!"
          }
        })

      # Should redirect (successful login)
      assert redirected_to(conn)

      # Verify DB preferences were NOT overwritten
      cookies = Consent.retrieve_cookies(user.id)
      assert length(cookies) == 1

      cookie = hd(cookies)
      assert cookie.value == existing_value
      refute cookie.value == browser_value
    end

    test "handles login without browser cookies gracefully", %{conn: conn} do
      # Create a user with password
      user = user_fixture(%{password: "valid_password123!"})

      # No browser cookie set
      conn =
        conn
        |> Plug.Test.init_test_session([])
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => "valid_password123!"
          }
        })

      # Should redirect (successful login)
      assert redirected_to(conn)

      # Verify no cookies were created (nothing to sync)
      cookies = Consent.retrieve_cookies(user.id)
      assert cookies == []
    end

    test "does not create duplicate records on subsequent logins", %{conn: conn} do
      # Create a user with password
      user = user_fixture(%{password: "valid_password123!"})

      cookie_value =
        ~s({"necessary":true,"functionality":true,"analytics":false,"targeting":false})

      # First login with browser cookie
      conn
      |> Plug.Test.init_test_session([])
      |> put_req_cookie("_cky_opt_choices", cookie_value)
      |> post(Routes.user_session_path(conn, :create), %{
        "user" => %{
          "email" => user.email,
          "password" => "valid_password123!"
        }
      })

      # Verify one record exists
      assert length(Consent.retrieve_cookies(user.id)) == 1

      # Second login with same browser cookie
      build_conn()
      |> Plug.Test.init_test_session([])
      |> put_req_cookie("_cky_opt_choices", cookie_value)
      |> post(Routes.user_session_path(conn, :create), %{
        "user" => %{
          "email" => user.email,
          "password" => "valid_password123!"
        }
      })

      # Should still have only one record (no duplicates)
      cookies = Consent.retrieve_cookies(user.id)
      assert length(cookies) == 1
    end
  end

  describe "cookie_consent controller " do
    setup [:setup_session]

    test "handle cookie consent persist and retrieve", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn1 =
        post(
          conn,
          Routes.cookie_consent_path(conn, :persist_cookies),
          cookies: [
            %{
              duration: "Tue, 26 Apr 2022 18:17:21 GMT",
              expiresIso: "2022-04-26T18:17:21.264Z",
              name: "_cky_opt_in",
              value: "true"
            }
          ]
        )

      assert keys1 = json_response(conn1, 200)
      assert Map.get(keys1, "info") == "cookies persisted"

      conn2 =
        get(
          conn,
          Routes.cookie_consent_path(conn, :retrieve)
        )

      assert keys2 = json_response(conn2, 200)

      assert keys2 == [
               %{
                 "expiration" => "2022-04-26T18:17:21Z",
                 "name" => "_cky_opt_in",
                 "value" => "true"
               }
             ]
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {b}",
                "score" => 11,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {c}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(
        %{title: "one", max_attempts: 2, content: content},
        :publication,
        :project,
        :author,
        :activity
      )

    attrs = %{
      graded: true,
      max_attempts: 1,
      title: "page1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
    }

    map = Seeder.add_page(map, attrs, :page)

    Seeder.attach_pages_to(
      [map.page1, map.page2, map.page.resource],
      map.container.resource,
      map.container.revision,
      map.publication
    )

    section =
      section_fixture(%{
        context_id: "some-context-id",
        base_project_id: map.project.id,
        institution_id: map.institution.id,
        open_and_free: false
      })

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, [])
      |> log_in_author(map.author)
      |> log_in_user(user)

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     user: user,
     project: map.project,
     publication: map.publication,
     section: section,
     revision: map.revision1,
     page_revision: map.page.revision}
  end
end
