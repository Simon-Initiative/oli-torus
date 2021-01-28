defmodule OliWeb.ActivityControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityEditor

  alias Oli.Publishing

  setup [:project_seed]

  describe "get resource" do

    test "retrieves the unpublished activity", %{conn: conn, project: project, activity_id: activity_id} do

      conn = get(conn, Routes.activity_path(conn, :retrieve, project.slug, activity_id))

      assert %{ "objectives" => %{}, "content" => %{"stem" => "1"}, "authoring" => %{"parts" => [part]} } = json_response(conn, 200)
      assert %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"} = part
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
