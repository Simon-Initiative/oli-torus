defmodule OliWeb.CookieConsentControllerTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles

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

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, [])
      |> assign_current_author(map.author)
      |> assign_current_user(user)

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
