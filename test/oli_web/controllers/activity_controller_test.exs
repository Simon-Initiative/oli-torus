defmodule OliWeb.ActivityControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Publishing.AuthoringResolver

  setup [:project_seed]

  describe "get resource for delivery" do

    test "retrieves the published activity", %{conn: conn, section: section, activity_id: activity_id} do

      conn = get(conn, Routes.activity_path(conn, :retrieve_delivery, section.id, activity_id))

      assert %{"content" => %{"stem" => "1"}} = json_response(conn, 200)
    end

  end

  describe "create and then delete a secondary resource" do

    test "fails when attempting to delete an activity primary document", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      conn = delete(conn, Routes.activity_path(conn, :delete, project.slug, activity_id, %{"lock" => revision.resource_id }))
      assert response(conn, 400)
    end

    test "creates a secondary resource for an activity", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      original_conn = conn

      update = %{"title" => "A title", "content" => %{"1" => "2"}}
      conn = post(conn, Routes.activity_path(conn, :create_secondary, project.slug, activity_id), update)

      assert %{ "result" => "success", "resource_id" => id } = json_response(conn, 201)

      r = AuthoringResolver.from_resource_id(project.slug, id)
      assert r.title == "A title"
      assert r.content["1"] == "2"
      assert r.deleted == false
      assert r.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("secondary")

      conn = delete(original_conn, Routes.activity_path(original_conn, :delete, project.slug, id, %{"lock" => revision.resource_id }))
      assert %{ "result" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, id)
      assert r.deleted == true
    end

  end

  describe "get resource" do

    test "retrieves the unpublished activity", %{conn: conn, project: project, activity_id: activity_id} do

      conn = get(conn, Routes.activity_path(conn, :retrieve, project.slug, activity_id))

      assert %{ "objectives" => %{}, "content" => %{"stem" => "1"}, "authoring" => %{"parts" => [part]} } = json_response(conn, 200)
      assert %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"} = part
    end

    test "updates the title", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title"}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock" => revision.resource_id}), update)

      assert %{ "result" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.title == "updated title"

    end

    test "updates content (and title), but not authoring", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title", "content" => %{"1" => "2"}}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock" => revision.resource_id}), update)

      assert %{ "result" => "success" } = json_response(conn, 200)

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
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock" => revision.resource_id}), update)

      assert %{ "result" => "success" } = json_response(conn, 200)

      r = AuthoringResolver.from_resource_id(project.slug, activity_id)
      assert r.content["stem"] == "1"
      assert hd(r.content["authoring"]["parts"])["evaluationStrategy"] == "none"

    end

    test "including an invalid key gets rejected", %{conn: conn, project: project, activity_id: activity_id, revision1: revision} do

      update = %{"title" => "updated title", "resource_id" => "2"}
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock" => revision.resource_id}), update)
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
      conn = put(conn, Routes.activity_path(conn, :update, project.slug, activity_id, %{"lock" => revision.resource_id}), update)

      assert %{ "result" => "success" } = json_response(conn, 200)

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
