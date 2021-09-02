defmodule OliWeb.TagControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder

  defp again(conn, user) do
    recycle(conn)
    |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:author))
  end

  describe "tag endpoint" do
    setup [:setup_session]

    test "can list all tags", %{
      conn: conn,
      project: project
    } do
      conn =
        get(
          conn,
          Routes.tag_path(conn, :index, project.slug)
        )

      assert %{"result" => "success", "tags" => tags} = json_response(conn, 200)
      assert length(tags) == 2
    end

    test "can create a tag", %{
      conn: conn,
      project: project,
      author: user
    } do
      conn =
        post(
          conn,
          Routes.tag_path(conn, :new, project.slug),
          %{"title" => "my new tag"}
        )

      assert %{"result" => "success", "tag" => %{"title" => "my new tag", "id" => _}} =
               json_response(conn, 200)

      conn = again(conn, user)

      conn =
        get(
          conn,
          Routes.tag_path(conn, :index, project.slug)
        )

      assert %{"result" => "success", "tags" => tags} = json_response(conn, 200)
      assert length(tags) == 3
    end

    test "handles unknown project via 404", %{
      conn: conn
    } do
      conn =
        get(
          conn,
          Routes.tag_path(conn, :index, "this_does_not_exist")
        )

      assert response(conn, 404)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_tag("easy", :easy)
      |> Seeder.create_tag("hard", :hard)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, map: map, author: map.author, project: map.project}
  end
end
