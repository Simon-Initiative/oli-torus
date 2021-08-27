defmodule OliWeb.ResourceAttemptStateControllerTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles

  defp again(conn, user) do
    recycle(conn)
    |> Pow.Plug.assign_current_user(
      user,
      OliWeb.Pow.PowHelpers.get_pow_config(:user)
    )
  end

  describe "attempt extrinsic endpoints" do
    setup [:setup_session]

    test "can read and update", %{
      conn: conn,
      section: section,
      user: user,
      attempt: attempt
    } do
      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        get(
          conn,
          Routes.resource_attempt_state_path(conn, :read, section.slug, attempt.attempt_guid)
        )

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 0

      conn = again(conn, user)

      conn =
        put(
          conn,
          Routes.resource_attempt_state_path(conn, :upsert, section.slug, attempt.attempt_guid),
          %{
            "one" => "1",
            "two" => 2,
            "three" => 3
          }
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)

      conn =
        get(
          conn,
          Routes.resource_attempt_state_path(conn, :read, section.slug, attempt.attempt_guid)
        )

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 3

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == 2
      assert Map.get(keys, "three") == 3

      conn = again(conn, user)

      conn =
        delete(
          conn,
          Routes.resource_attempt_state_path(conn, :delete, section.slug, attempt.attempt_guid) <>
            "?keys[]=two&keys[]=three"
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)

      conn =
        get(
          conn,
          Routes.resource_attempt_state_path(conn, :read, section.slug, attempt.attempt_guid)
        )

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 1

      assert Map.get(keys, "one") == "1"
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()
    user2 = user_fixture()

    map = Seeder.base_project_with_resource2()

    section =
      section_fixture(%{
        context_id: "some-context-id",
        base_project_id: map.project.id,
        institution_id: map.institution.id,
        open_and_free: false
      })

    lti_params =
      Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)

    cache_lti_params("params-key", lti_params)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    map = Map.put(map, :the_page, %{resource: map.page1, revision: map.revision1})
    map = Map.put(map, :section, section)
    map = Map.put(map, :user, user)

    map =
      Seeder.create_resource_attempt(
        map,
        %{attempt_number: 1},
        :user,
        :the_page,
        :attempt
      )

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     user: user,
     user2: user2,
     attempt: map.attempt,
     project: map.project,
     publication: map.publication,
     section: section}
  end
end
