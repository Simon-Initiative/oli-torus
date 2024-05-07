defmodule OliWeb.AttemptControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.Core

  describe "bulk activity attempt request" do
    setup [:setup_session]

    test "can fetch many activity attempts", %{
      conn: conn,
      map: map
    } do
      activity_attempt_guids = [
        map.activity_attempt1.attempt_guid,
        map.activity_attempt2.attempt_guid
      ]

      conn =
        post(
          conn,
          Routes.attempt_path(conn, :bulk_retrieve, map.section.slug),
          %{"attemptGuids" => activity_attempt_guids}
        )

      assert %{"result" => "success", "activityAttempts" => attempts} = json_response(conn, 200)

      first_activity_attempt =
        Enum.find(attempts, fn a -> a["attemptGuid"] == map.activity_attempt1.attempt_guid end)

      assert length(first_activity_attempt["partAttempts"]) == 1

      second_activity_attempt =
        Enum.find(attempts, fn a -> a["attemptGuid"] == map.activity_attempt2.attempt_guid end)

      part_attempts = second_activity_attempt["partAttempts"]
      assert length(part_attempts) == 3

      # Verify that the parts that had multiple attempts that the endpoint correctly
      # returns only the latest part attempt for those parts
      part1_attempt = Enum.find(part_attempts, fn p -> p["partId"] == "1" end)
      assert part1_attempt["attemptNumber"] == 3

      part3_attempt = Enum.find(part_attempts, fn p -> p["partId"] == "3" end)
      assert part3_attempt["attemptNumber"] == 2
    end
  end

  describe "reset activity attempt" do
    setup [:setup_session]

    test "use reset button sets survey_id field correctly", %{
      conn: conn,
      map: map
    } do
      # Simulate the user clicking the reset button
      conn =
        post(
          conn,
          Routes.attempt_path(
            conn,
            :new_activity,
            map.section.slug,
            map.activity_attempt1.attempt_guid
          ),
          %{survey_id: "1010"}
        )

      # Verify that the response is successful
      assert %{"type" => "success", "attemptState" => attempt_state, "model" => _model} =
               json_response(conn, 200)

      # Verify that the survey_id was set correctly
      assert Core.get_activity_attempt_by(attempt_guid: attempt_state["attemptGuid"]).survey_id ==
               "1010"
    end
  end

  describe "activity and attempt already submitted" do
    setup [:setup_session]

    test "cannot submit an already submitted activity in a graded page", %{
      conn: conn,
      map: map
    } do
      # Mark activity attempt as submitted
      {:ok, activity_attempt} =
        Core.get_latest_activity_attempts(map.attempt1.id)
        |> hd
        |> Core.update_activity_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Submit activity attempt endpoint
      conn =
        put(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{activity_attempt.attempt_guid}",
          %{
            "section_slug" => map.section.slug,
            "activity_attempt_guid" => activity_attempt.attempt_guid,
            "partInputs" => []
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end

    test "cannot change an already input submitted in a graded page", %{
      conn: conn,
      map: map
    } do
      # Mark part attempt as submitted
      {:ok, part_attempt} =
        Core.get_latest_part_attempts(map.activity_attempt1.attempt_guid)
        |> hd
        |> Core.update_part_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Save activity attempt endpoint
      conn =
        patch(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{map.activity_attempt1.attempt_guid}",
          %{
            "activity_attempt_guid" => map.activity_attempt1.attempt_guid,
            "partInputs" => [
              %{
                "attemptGuid" => part_attempt.attempt_guid,
                "response" => %{"input" => "Hello World"}
              }
            ]
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end

    test "cannot save an already part attempt submitted in a graded page", %{
      conn: conn,
      map: map
    } do
      # Mark part attempt as submitted
      {:ok, part_attempt} =
        Core.get_latest_part_attempts(map.activity_attempt1.attempt_guid)
        |> hd
        |> Core.update_part_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Save part attempt endpoint
      conn =
        patch(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{map.activity_attempt1.attempt_guid}/part_attempt/#{part_attempt.attempt_guid}",
          %{
            "activity_attempt_guid" => map.activity_attempt1.attempt_guid,
            "part_attempt_guid" => part_attempt.attempt_guid,
            "response" => "Hello World"
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end

    test "cannot submit an already submitted activity in a adaptive page", %{
      conn: conn,
      map: map
    } do
      # Mark activity attempt as submitted
      {:ok, activity_attempt} =
        Core.get_latest_activity_attempts(map.adaptive_attempt1.id)
        |> hd
        |> Core.update_activity_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Submit activity attempt endpoint
      conn =
        put(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{activity_attempt.attempt_guid}",
          %{
            "section_slug" => map.section.slug,
            "activity_attempt_guid" => activity_attempt.attempt_guid,
            "partInputs" => []
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end

    test "cannot change an already input submitted in a adaptive page", %{
      conn: conn,
      map: map
    } do
      # Mark part attempt as submitted
      {:ok, part_attempt} =
        Core.get_latest_part_attempts(map.adaptive_activity_attempt1.attempt_guid)
        |> hd
        |> Core.update_part_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Save activity attempt endpoint
      conn =
        patch(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{map.adaptive_activity_attempt1.attempt_guid}",
          %{
            "activity_attempt_guid" => map.adaptive_activity_attempt1.attempt_guid,
            "partInputs" => [
              %{
                "attemptGuid" => part_attempt.attempt_guid,
                "response" => %{"input" => "Hello World"}
              }
            ]
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end

    test "cannot save an already part attempt submitted in a adaptive page", %{
      conn: conn,
      map: map
    } do
      # Mark part attempt as submitted
      {:ok, part_attempt} =
        Core.get_latest_part_attempts(map.adaptive_activity_attempt1.attempt_guid)
        |> hd
        |> Core.update_part_attempt(%{
          lifecycle_state: "submitted",
          date_submitted: DateTime.utc_now()
        })

      # Save part attempt endpoint
      conn =
        patch(
          conn,
          ~p"/api/v1/state/course/#{map.section.slug}/activity_attempt/#{map.adaptive_activity_attempt1.attempt_guid}/part_attempt/#{part_attempt.attempt_guid}",
          %{
            "activity_attempt_guid" => map.adaptive_activity_attempt1.attempt_guid,
            "part_attempt_guid" => part_attempt.attempt_guid,
            "response" => "Hello World"
          }
        )

      assert %{
               "message" =>
                 "These changes could not be saved as this attempt may have already been submitted",
               "error" => true
             } =
               json_response(conn, 403)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :activity_a)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :adaptive_activity)
      |> Seeder.add_page(%{graded: true}, :graded_page)
      |> Seeder.add_adaptive_page(:adaptive_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: nil},
        :activity_a,
        :attempt1,
        :activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :activity_attempt1,
        :part1_attempt1
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 2},
        :user1,
        :page1,
        :revision1,
        :attempt2
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: nil},
        :activity_a,
        :attempt2,
        :activity_attempt2
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :activity_attempt2,
        :part1_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 2},
        %Part{id: "1", responses: [], hints: []},
        :activity_attempt2,
        :part1_attempt2
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 3},
        %Part{id: "1", responses: [], hints: []},
        :activity_attempt2,
        :part1_attempt3
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "2", responses: [], hints: []},
        :activity_attempt2,
        :part2_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "3", responses: [], hints: []},
        :activity_attempt2,
        :part3_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 2},
        %Part{id: "3", responses: [], hints: []},
        :activity_attempt2,
        :part3_attempt2
      )
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :adaptive_page,
        :adaptive_page_revision,
        :adaptive_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: nil},
        :adaptive_activity,
        :adaptive_attempt1,
        :adaptive_activity_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :adaptive_activity_attempt1,
        :adaptive_part1_attempt1
      )

    user = map.user1

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> OliWeb.Common.LtiSession.put_session_lti_params(lti_params_id)

    {:ok, conn: conn, map: map}
  end
end
