defmodule OliWeb.PageLifecycleTest do
  use OliWeb.ConnCase

  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.Core
  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

  describe "set progress completed tests" do
    setup [:setup_session]

    test "can set progress", %{
      conn: conn,
      map: map
    } do
      attempt = map.ungraded_page_user1_attempt1

      assert_progress(0.0, attempt.attempt_guid)

      conn =
        post(
          conn,
          Routes.page_lifecycle_path(conn, :transition),
          %{"attempt_guid" => attempt.attempt_guid, "action" => "mark_completed"}
        )

      assert %{"result" => "success", "commandResult" => "success"} = json_response(conn, 200)

      assert_progress(1.0, attempt.attempt_guid)
    end

    test "fails when guid is bad", %{
      conn: conn
    } do
      conn =
        post(
          conn,
          Routes.page_lifecycle_path(conn, :transition),
          %{"attempt_guid" => "this_guid_does_not_exist", "action" => "mark_completed"}
        )

      assert %{"result" => "success", "commandResult" => "failure"} = json_response(conn, 200)
    end
  end

  defp assert_progress(progress, guid) do
    assert Core.get_resource_access_from_guid(guid).progress == progress
  end

  defp setup_session(%{conn: conn}) do
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
                "score" => 1,
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
      |> Seeder.add_activity(%{title: "one", max_attempts: 2, content: content}, :activity)
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)

    Seeder.ensure_published(map.publication.id)

    map =
      Seeder.add_page(
        map,
        %{
          title: "page1",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => []}
        },
        :ungraded_page
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content},
        :activity,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity_attempt1,
        :ungraded_page_user1_activity_attempt1_part1_attempt1
      )

    user = map.user1

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_user(user)

    {:ok, conn: conn, map: map}
  end
end
