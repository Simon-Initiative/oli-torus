defmodule OliWeb.AttemptControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Oli.Activities.Model.Part

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

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :activity_a)
      |> Seeder.add_page(%{graded: true}, :graded_page)
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :page1,
        :revision1,
        :attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: %{}},
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
        %{attempt_number: 1, transformed_model: %{}},
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

    user = map.user1

    lti_params =
      Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)

    cache_lti_params("params-key", lti_params)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn, map: map}
  end
end
