defmodule OliWeb.Api.LtiControllerTest do
  use OliWeb.ConnCase

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Delivery.Sections

  defp accept_json(%{conn: conn}) do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup [:accept_json]

  describe "authoring launch_details" do
    setup [:setup_project]

    test "returns LTI launch details", %{conn: conn, project: project, activity_id: activity_id} do
      conn = get(conn, ~p"/api/v1/lti/projects/#{project.slug}/launch_details/#{activity_id}")
      assert json_response(conn, 200)["name"] == "some name"

      assert json_response(conn, 200)["launch_params"]["iss"] == Oli.Utils.get_base_url()
      assert json_response(conn, 200)["launch_params"]["client_id"] == "some client_id"

      assert json_response(conn, 200)["launch_params"]["target_link_uri"] ==
               "some target_link_uri"

      assert json_response(conn, 200)["launch_params"]["login_url"] == "some login_url"
      assert json_response(conn, 200)["launch_params"]["login_hint"] != nil
      assert json_response(conn, 200)["launch_params"]["status"] != nil
    end
  end

  describe "delivery launch_details" do
    setup [:setup_section]

    test "returns LTI launch details", %{conn: conn, section: section, activity_id: activity_id} do
      conn = get(conn, ~p"/api/v1/lti/sections/#{section.slug}/launch_details/#{activity_id}")
      assert json_response(conn, 200)["name"] == "some name"

      assert json_response(conn, 200)["launch_params"]["iss"] == Oli.Utils.get_base_url()
      assert json_response(conn, 200)["launch_params"]["client_id"] == "some client_id"

      assert json_response(conn, 200)["launch_params"]["target_link_uri"] ==
               "some target_link_uri"

      assert json_response(conn, 200)["launch_params"]["login_url"] == "some login_url"
      assert json_response(conn, 200)["launch_params"]["login_hint"] != nil
      assert json_response(conn, 200)["launch_params"]["status"] != nil
    end
  end

  defp create_lti_external_tool_activity() do
    attrs = %{
      "client_id" => "some client_id",
      "custom_params" => "some custom_params",
      "description" => "some description",
      "keyset_url" => "some keyset_url",
      "login_url" => "some login_url",
      "name" => "some name",
      "redirect_uris" => "some redirect_uris",
      "target_link_uri" => "some target_link_uri"
    }

    PlatformExternalTools.register_lti_external_tool_activity(attrs)
  end

  def setup_section(%{conn: conn}) do
    {:ok, seeds} = setup_project(%{conn: conn})

    {:ok, pub1} = Publishing.publish_project(seeds.project, "some changes", seeds.author.id)

    {:ok, section} =
      Sections.create_section(%{
        title: "3",
        registration_open: true,
        open_and_free: true,
        context_id: UUID.uuid4(),
        institution_id: seeds.institution.id,
        base_project_id: seeds.project.id,
        analytics_version: :v1
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub1)

    student = user_fixture(%{independent_learner: false})

    Sections.enroll(student.id, section.id, [
      Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
    ])

    conn =
      log_in_user(
        conn,
        student
      )

    {:ok,
     Map.merge(seeds, %{
       conn: conn,
       section: section,
       student: student
     })}
  end

  def setup_project(%{conn: conn}) do
    {:ok, {_platform_instance, activity_registration, _deployment}} =
      create_lti_external_tool_activity()

    seeds = Oli.Seeder.base_project_with_resource2()

    project = Map.get(seeds, :project)
    revision = Map.get(seeds, :revision1)
    author = Map.get(seeds, :author)

    content = %{
      "openInNewTab" => "true",
      "authoring" => %{
        "parts" => []
      }
    }

    {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    {:ok, {%{slug: slug2, resource_id: activity_id2}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    seeds = Map.put(seeds, :activity_id, activity_id) |> Map.put(:activity_id2, activity_id2)

    update = %{
      "content" => %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "activity-reference",
            "id" => "1",
            "activitySlug" => slug
          },
          %{
            "type" => "activity-reference",
            "id" => "2",
            "activitySlug" => slug2
          }
        ]
      }
    }

    PageEditor.acquire_lock(project.slug, revision.slug, author.email)
    assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

    conn =
      log_in_author(
        conn,
        seeds.author
      )

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
