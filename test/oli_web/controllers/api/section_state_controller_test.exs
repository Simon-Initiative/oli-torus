defmodule OliWeb.ExtrinsicStateControllerTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles

  defp again(conn, user) do
    recycle(conn)
    |> log_in_user(user)
  end

  describe "section extrinsic endpoints" do
    setup [:setup_session]

    test "can read and update", %{
      conn: conn,
      section: section,
      user: user
    } do
      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 0

      conn = again(conn, user)

      conn =
        put(
          conn,
          Routes.section_state_path(conn, :upsert, section.slug),
          %{
            "one" => "1",
            "two" => 2,
            "three" => 3
          }
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)

      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 3

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == 2
      assert Map.get(keys, "three") == 3

      conn = again(conn, user)

      conn =
        delete(
          conn,
          Routes.section_state_path(conn, :delete, section.slug) <>
            "?keys[]=two&keys[]=three"
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)
      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 1

      assert Map.get(keys, "one") == "1"
    end

    test "not found when not enrolled in section", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))
      assert response(conn, 404)
    end

    test "section storage is unique to each user", %{
      conn: conn,
      section: section,
      user: user,
      user2: user2
    } do
      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _enrollment} =
        Sections.enroll(user2.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        put(
          conn,
          Routes.section_state_path(conn, :upsert, section.slug),
          %{
            "one" => "1",
            "two" => 2,
            "three" => 3
          }
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)

      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 3

      conn = again(conn, user2)

      conn =
        put(
          conn,
          Routes.section_state_path(conn, :upsert, section.slug),
          %{
            "user2" => "2"
          }
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user2)

      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 1

      conn = again(conn, user)

      conn = get(conn, Routes.section_state_path(conn, :read, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 3
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

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(map.author)
      |> log_in_user(user)

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     user: user,
     user2: user2,
     project: map.project,
     publication: map.publication,
     section: section}
  end
end
