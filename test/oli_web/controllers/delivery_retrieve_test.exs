defmodule OliWeb.DeliveryRetrieveTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias OliWeb.Common.LtiSession

  setup [:setup_session]

  describe "get resource for delivery" do
    test "retrieves the published activity", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      conn = get(conn, Routes.activity_path(conn, :retrieve_delivery, section.slug, activity_id))

      assert %{"content" => %{"stem" => "1"}} = json_response(conn, 200)
    end
  end

  describe "bulk get resource for delivery" do
    test "retrieves the published pages", %{
      conn: conn,
      section: section,
      page_revision1: rev1,
      page_revision2: rev2
    } do
      conn =
        post(conn, Routes.activity_path(conn, :bulk_retrieve_delivery, section.slug), %{
          "resourceIds" => [rev1.resource_id, rev2.resource_id]
        })

      assert %{"results" => results} = json_response(conn, 200)
      assert length(results) == 2
    end
  end

  defp insert_page(map, tag) do
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

    Seeder.add_page(map, attrs, tag)
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
      |> insert_page(:new_page1)
      |> insert_page(:new_page2)

    Seeder.attach_pages_to(
      [map.page1, map.page2, map.new_page1.resource, map.new_page2.resource],
      map.container.resource,
      map.container.revision,
      map.publication
    )

    section =
      section_fixture(%{
        context_id: "some-context-id",
        base_project_id: map.project.id,
        institution_id: map.institution.id
      })

    Oli.Accounts.update_user(user, %{"sub" => "a73d59affc5b2c4cd493"})
    Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

    lti_params =
      Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

    cache_lti_params("params-key", lti_params)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> LtiSession.put_user_params("params-key")
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
     conn: conn,
     map: map,
     activity_id: Map.get(map, :activity).resource.id,
     author: map.author,
     institution: map.institution,
     user: user,
     project: map.project,
     publication: map.publication,
     section: section,
     revision: map.revision1,
     page_revision1: map.new_page1.revision,
     page_revision2: map.new_page2.revision}
  end
end
