defmodule OliWeb.ObjectivesControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo

  setup [:project_seed]

  def remove_author(author, project) do
    author_project = Repo.get_by(AuthorProject, %{author_id: author.id, project_id: project.id})
    Repo.delete(author_project)
  end

  describe "GET operation via objectives service" do
    test "lists all objectives", %{conn: conn, project: project} do
      conn = get(conn, Routes.objectives_path(conn, :index, project.slug))

      assert objectives = json_response(conn, 200)

      # make sure they are all there
      assert length(objectives) == 6

      # and that their titles are correct and the hierarchy is correct
      by_title = Enum.reduce(objectives, %{}, fn o, m -> Map.put(m, o["title"], o) end)
      assert Map.get(by_title, "parent1")["parentId"] == nil
      assert Map.get(by_title, "parent2")["parentId"] == nil
      assert Map.get(by_title, "child1")["parentId"] == Map.get(by_title, "parent1")["id"]
      assert Map.get(by_title, "child2")["parentId"] == Map.get(by_title, "parent1")["id"]
      assert Map.get(by_title, "child3")["parentId"] == Map.get(by_title, "parent1")["id"]
      assert Map.get(by_title, "child4")["parentId"] == Map.get(by_title, "parent2")["id"]
    end

    test "GET fails when project does not exist", %{conn: conn} do
      conn = get(conn, Routes.objectives_path(conn, :index, "this_id_does_not_exist"))
      assert response(conn, 404)
    end

    test "GET fails when author has no access to project", %{
      conn: conn,
      project: project,
      author: author
    } do
      remove_author(author, project)

      conn = get(conn, Routes.objectives_path(conn, :index, project.slug))
      assert response(conn, 403)
    end
  end

  describe "POST operation to create an objective" do
    test "creates an objective as a child objective", %{
      conn: conn,
      project: project,
      child1: child1
    } do
      conn =
        post(conn, Routes.objectives_path(conn, :create, project.slug), %{
          "title" => "new one",
          "parentId" => child1.resource.id
        })

      assert %{"result" => "success", "resourceId" => id} = json_response(conn, 201)

      rev = AuthoringResolver.from_resource_id(project.slug, child1.resource.id)
      assert rev.children == [id]

      rev = AuthoringResolver.from_resource_id(project.slug, id)
      assert rev.title == "new one"
    end

    test "creates a top-level objective", %{conn: conn, project: project} do
      conn =
        post(conn, Routes.objectives_path(conn, :create, project.slug), %{"title" => "new one"})

      assert %{"result" => "success", "resourceId" => id} = json_response(conn, 201)

      rev = AuthoringResolver.from_resource_id(project.slug, id)
      assert rev.title == "new one"
    end

    test "create fails when author has no access to project", %{
      conn: conn,
      project: project,
      author: author
    } do
      remove_author(author, project)

      conn = post(conn, Routes.objectives_path(conn, :create, project.slug), %{"title" => "test"})
      assert response(conn, 403)
    end

    test "fails when title is missing from payload", %{conn: conn, project: project} do
      conn = post(conn, Routes.objectives_path(conn, :create, project.slug), %{})
      assert response(conn, 400)
    end

    test "fails when project does not exist", %{conn: conn} do
      conn =
        post(conn, Routes.objectives_path(conn, :create, "this_id_does_not_exist"), %{
          "title" => "new title"
        })

      assert response(conn, 404)
    end
  end

  describe "PUT operation to update an objective" do
    test "updates the title of an objective", %{conn: conn, project: project, child1: child1} do
      conn =
        put(conn, Routes.objectives_path(conn, :update, project.slug, child1.resource.id), %{
          "title" => "new title"
        })

      assert %{"result" => "success"} = json_response(conn, 200)

      rev = AuthoringResolver.from_resource_id(project.slug, child1.resource.id)
      assert rev.title == "new title"
    end

    test "update fails when author has no access to project", %{
      conn: conn,
      project: project,
      author: author
    } do
      remove_author(author, project)

      conn =
        put(conn, Routes.objectives_path(conn, :update, project.slug, 1), %{"title" => "test"})

      assert response(conn, 403)
    end

    test "fails when objective does not exist", %{conn: conn, project: project} do
      conn =
        put(conn, Routes.objectives_path(conn, :update, project.slug, 919_191_919), %{
          "title" => "new title"
        })

      assert response(conn, 404)
    end

    test "fails when title is missing from payload", %{
      conn: conn,
      project: project,
      child1: child1
    } do
      conn =
        put(conn, Routes.objectives_path(conn, :update, project.slug, child1.resource.id), %{})

      assert response(conn, 400)
    end

    test "fails when project does not exist", %{conn: conn, child1: child1} do
      conn =
        put(
          conn,
          Routes.objectives_path(conn, :update, "this_id_does_not_exist", child1.resource.id),
          %{"title" => "new title"}
        )

      assert response(conn, 404)
    end
  end

  def project_seed(%{conn: conn}) do
    seeds =
      Oli.Seeder.base_project_with_resource2()
      |> Oli.Seeder.add_objective("child1", :child1)
      |> Oli.Seeder.add_objective("child2", :child2)
      |> Oli.Seeder.add_objective("child3", :child3)
      |> Oli.Seeder.add_objective("child4", :child4)
      |> Oli.Seeder.add_objective_with_children("parent1", [:child1, :child2, :child3], :parent1)
      |> Oli.Seeder.add_objective_with_children("parent2", [:child4], :parent2)

    conn =
      log_in_author(
        conn,
        seeds.author
      )

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
