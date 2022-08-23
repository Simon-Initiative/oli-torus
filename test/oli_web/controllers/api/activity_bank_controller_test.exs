defmodule OliWeb.Api.ActivityBankControllerTest do
  use OliWeb.ConnCase
  alias Oli.Seeder

  setup [:project_seed]

  describe "activity bank endpoint tests" do
    test "can launch activity bank editor", %{conn: conn, project: project} do
      conn = get(conn, Routes.activity_bank_path(conn, :index, project.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.ActivityBank\" data-react-props=\""
    end

    test "can query all", %{conn: conn, project: project} do
      payload = %{"logic" => %{"conditions" => nil}, "paging" => %{"limit" => 5, "offset" => 0}}
      conn = post(conn, Routes.activity_bank_path(conn, :retrieve, project.slug), payload)

      assert keys = json_response(conn, 200)
      assert keys["queryResult"]["totalCount"] == 6
      assert keys["queryResult"]["rowCount"] == 5
      assert length(keys["queryResult"]["rows"]) == 5
    end

    test "can query using an offset", %{conn: conn, project: project} do
      payload = %{"logic" => %{"conditions" => nil}, "paging" => %{"limit" => 5, "offset" => 5}}
      conn = post(conn, Routes.activity_bank_path(conn, :retrieve, project.slug), payload)

      assert keys = json_response(conn, 200)
      assert keys["queryResult"]["totalCount"] == 6
      assert keys["queryResult"]["rowCount"] == 1
      assert length(keys["queryResult"]["rows"]) == 1
    end

    test "can query using conditional logic", %{conn: conn, project: project} do
      payload = %{
        "logic" => %{
          "conditions" => %{"fact" => "objectives", "operator" => "contains", "value" => [2]}
        },
        "paging" => %{"limit" => 5, "offset" => 0}
      }

      conn = post(conn, Routes.activity_bank_path(conn, :retrieve, project.slug), payload)

      assert keys = json_response(conn, 200)
      assert keys["queryResult"]["totalCount"] == 3
      assert keys["queryResult"]["rowCount"] == 3
      assert length(keys["queryResult"]["rows"]) == 3
    end
  end

  def project_seed(%{conn: conn}) do
    map = Oli.Seeder.base_project_with_resource2()

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1]},
        title: "1",
        content: %{model: %{stem: "this is the question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1, 2]},
        title: "2",
        content: %{model: %{stem: "and another"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1]},
        title: "3",
        content: %{model: %{stem: "this is the question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1, 2]},
        title: "4",
        content: %{model: %{stem: "and another"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1]},
        title: "5",
        content: %{model: %{stem: "this is the question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1, 2]},
        title: "6",
        content: %{model: %{stem: "and another"}}
      },
      map.publication,
      map.project,
      map.author
    )

    # NOTICE, this is a deleted activity:
    Seeder.create_activity(
      %{
        scope: :banked,
        deleted: true,
        objectives: %{"1" => [1, 2]},
        title: "7",
        content: %{model: %{stem: "and another"}}
      },
      map.publication,
      map.project,
      map.author
    )

    # NOTICE, this is an embedded activity:
    Seeder.create_activity(
      %{
        scope: :embedded,
        objectives: %{"1" => [1, 2]},
        title: "8",
        content: %{model: %{stem: "and another"}}
      },
      map.publication,
      map.project,
      map.author
    )

    conn =
      Pow.Plug.assign_current_user(
        conn,
        map.author,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )

    {:ok, Map.merge(%{conn: conn}, map)}
  end
end
