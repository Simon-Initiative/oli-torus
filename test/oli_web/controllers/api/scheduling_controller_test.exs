defmodule OliWeb.SchedulingControllerTest do
  use OliWeb.ConnCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Seeder
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias OliWeb.Router.Helpers, as: Routes

  defp again(conn, user) do
    recycle(conn)
    |> assign_current_user(user)
  end

  describe "scheduling controller tests" do
    setup [:setup_session]

    test "can access and update scheduled resources", %{
      conn: conn,
      map: map
    } do
      user = map.teacher

      conn =
        get(
          conn,
          Routes.scheduling_path(conn, :index, map.section.slug)
        )

      assert %{"result" => "success", "resources" => resources} = json_response(conn, 200)
      assert length(resources) == 3

      # Change the end date for all 3
      updates = Enum.map(resources, fn sr -> Map.put(sr, "end_date", "2024-01-02") end)

      conn =
        again(conn, user)
        |> put(
          Routes.scheduling_path(conn, :update, map.section.slug),
          %{"updates" => updates}
        )

      assert %{"result" => "success", "count" => 3} = json_response(conn, 200)

      conn =
        again(conn, user)
        |> get(Routes.scheduling_path(conn, :index, map.section.slug))

      assert %{"result" => "success", "resources" => resources} = json_response(conn, 200)
      assert length(resources) == 3

      Enum.each(resources, fn sr -> assert sr["end_date"] == "2024-01-02" end)
    end

    test "can access and clear scheduled resources", %{
      conn: conn,
      map: map
    } do
      user = map.teacher

      # Access the scheduling page for the first time
      conn =
        get(
          conn,
          Routes.scheduling_path(conn, :index, map.section.slug)
        )

      assert %{"result" => "success", "resources" => resources} = json_response(conn, 200)
      assert length(resources) == 3

      # Simulate setting the schedule for all 3 resources (change the start_date and end_date for all 3)
      updates =
        Enum.map(resources, fn sr ->
          Map.merge(sr, %{"start_date" => "2024-01-01", "end_date" => "2024-01-31"})
        end)

      conn =
        again(conn, user)
        |> put(
          Routes.scheduling_path(conn, :update, map.section.slug),
          %{"updates" => updates}
        )

      assert %{"result" => "success", "count" => 3} = json_response(conn, 200)

      # Check that start_date and end_date for all 3 resources are updated
      [sr1, sr2, sr3] = updates
      assert sr1["start_date"] == "2024-01-01"
      assert sr1["end_date"] == "2024-01-31"
      assert sr2["start_date"] == "2024-01-01"
      assert sr2["end_date"] == "2024-01-31"
      assert sr3["start_date"] == "2024-01-01"
      assert sr3["end_date"] == "2024-01-31"

      # Click the clear timelines button
      conn =
        again(conn, user)
        |> delete(Routes.scheduling_path(conn, :clear, map.section.slug))

      assert %{"result" => "success"} = json_response(conn, 200)

      # Access the scheduling page for the second time
      conn =
        again(conn, user)
        |> get(Routes.scheduling_path(conn, :index, map.section.slug))

      assert %{"result" => "success", "resources" => resources} = json_response(conn, 200)

      # Check that start_date and end_date for all 3 resources are nil (schedule is cleared)
      [sr1, sr2, sr3] = resources
      assert sr1["start_date"] == nil
      assert sr1["end_date"] == nil
      assert sr2["start_date"] == nil
      assert sr2["end_date"] == nil
      assert sr3["start_date"] == nil
      assert sr3["end_date"] == nil
    end

    test "can catch unauthorized user access", %{
      conn: conn,
      map: map
    } do
      user = map.someone_else

      conn =
        again(conn, user)
        |> get(Routes.scheduling_path(conn, :index, map.section.slug))

      assert response(conn, 401)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_user(
        %{
          preferences: %{timezone: "America/New_York"}
        },
        :teacher
      )
      |> Seeder.add_user(%{}, :someone_else)

    {:ok, initial_pub} = Publishing.publish_project(map.project, "some changes", map.author.id)

    {:ok, section} =
      Sections.create_section(%{
        title: "1",
        registration_open: true,
        context_id: UUID.uuid4(),
        institution_id: map.institution.id,
        base_project_id: map.project.id,
        publisher_id: map.project.publisher_id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(initial_pub)

    Sections.enroll(map.teacher.id, section.id, [
      Lti_1p3.Tool.ContextRoles.get_role(:context_instructor)
    ])

    map = Map.put(map, :section, section)

    user = map.teacher

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> assign_current_author(map.author)
      |> assign_current_user(user)

    {:ok, conn: conn, map: map}
  end
end
