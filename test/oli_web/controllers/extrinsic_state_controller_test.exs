defmodule OliWeb.ExtrinsicStateControllerTest do
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

  describe "global extrinsic endpoints" do
    setup [:setup_session]

    test "can read and update", %{
      conn: conn,
      section: section,
      user: user
    } do
      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.extrinsic_state_path(conn, :read_global))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 0

      conn = again(conn, user)

      conn =
        put(conn, Routes.extrinsic_state_path(conn, :upsert_global), %{"one" => "1", "two" => 2})

      assert _ = json_response(conn, 200)

      conn = again(conn, user)
      conn = get(conn, Routes.extrinsic_state_path(conn, :read_global))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 2

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == 2

      conn = again(conn, user)
      conn = delete(conn, Routes.extrinsic_state_path(conn, :delete_global) <> "?keys[]=two")

      assert _ = json_response(conn, 200)

      conn = again(conn, user)
      conn = get(conn, Routes.extrinsic_state_path(conn, :read_global))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 1

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == nil
    end
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

      conn = get(conn, Routes.extrinsic_state_path(conn, :read_section, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 0

      conn = again(conn, user)

      conn =
        put(
          conn,
          Routes.extrinsic_state_path(conn, :upsert_section, section.slug),
          %{
            "one" => "1",
            "two" => 2
          }
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)

      conn = get(conn, Routes.extrinsic_state_path(conn, :read_section, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 2

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == 2

      conn = again(conn, user)

      conn =
        delete(
          conn,
          Routes.extrinsic_state_path(conn, :delete_section, section.slug) <> "?keys[]=two"
        )

      assert _ = json_response(conn, 200)

      conn = again(conn, user)
      conn = get(conn, Routes.extrinsic_state_path(conn, :read_section, section.slug))

      assert keys = json_response(conn, 200)
      assert length(Map.keys(keys)) == 1

      assert Map.get(keys, "one") == "1"
      assert Map.get(keys, "two") == nil
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()
    user2 = user_fixture()

    map = Seeder.base_project_with_resource2()

    section =
      section_fixture(%{
        context_id: "some-context-id",
        project_id: map.project.id,
        publication_id: map.publication.id,
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
