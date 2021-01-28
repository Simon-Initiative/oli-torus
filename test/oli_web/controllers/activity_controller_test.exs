defmodule OliWeb.ActivityControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Publishing.AuthoringResolver

  setup [:project_seed]

  describe "get resource" do

    test "retrieves the unpublished activity", %{conn: conn, project: project, activity_id: activity_id} do

      conn = get(conn, Routes.activity_path(conn, :retrieve, project.slug, activity_id))

      assert %{ "objectives" => %{}, "content" => %{"stem" => "1"}, "authoring" => %{"parts" => [part]} } = json_response(conn, 200)
      assert %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"} = part
    end

    test "updates the title", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title"}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock_id" => revision.resource_id}), update)

      assert %{ "type" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.title == "updated title"

    end

    test "updates content (and title), but not authoring", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title", "content" => %{"1" => "2"}}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock_id" => revision.resource_id}), update)

      assert %{ "type" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.title == "updated title"
      assert r.content["1"] == "2"
      assert length(r.content["authoring"]["parts"]) == 1

    end

    test "updates authoring, but not content", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"authoring" => %{
        "parts" => [
          %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "none"}
        ]
      }}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock_id" => revision.resource_id}), update)

      assert %{ "type" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.content["stem"] == "1"
      assert hd(r.content["authoring"]["parts"])["evaluationStrategy"] == "none"

    end

    test "including an invalid key gets rejected", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title", "resource_id" => "2"}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock_id" => revision.resource_id}), update)
      assert response(conn, 400)

    end

    test "updates authoring and content", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{
        "content" => %{"1" => "2"},
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "none"}
          ]
        }
      }
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock_id" => revision.resource_id}), update)

      assert %{ "type" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.content["1"] == "2"
      assert hd(r.content["authoring"]["parts"])["evaluationStrategy"] == "none"

    end


  end

  def project_seed(%{conn: conn}) do

    content = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
        ]
      }
    }

    seeds = Oli.Seeder.base_project_with_resource2()

    project = Map.get(seeds, :project)
    revision = Map.get(seeds, :revision1)
    author = Map.get(seeds, :author)

    {:ok, {%{slug: slug, resource_id: activity_id}, _}} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])
    seeds = Map.put(seeds, :activity_id, activity_id)

    update = %{ "content" => %{ "model" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => slug, "purpose" => "none"}]}}
    PageEditor.acquire_lock(project.slug, revision.slug, author.email)
    assert {:ok, _} =  PageEditor.edit(project.slug, revision.slug, author.email, update)

    conn = Pow.Plug.assign_current_user(conn, seeds.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
