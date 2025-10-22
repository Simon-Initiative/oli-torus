defmodule OliWeb.Api.LtiControllerIntegrationTest do
  use OliWeb.ConnCase

  import Mox

  setup :verify_on_exit!

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Delivery.Sections

  defp accept_json(%{conn: conn}) do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup [:accept_json]

  describe "LTI API Response Structure Integration Tests" do
    setup [:setup_project, :setup_section]

    test "API response structure matches frontend component expectations for authoring", %{
      conn: conn,
      project: project,
      activity_id: activity_id
    } do
      conn = get(conn, ~p"/api/v1/lti/projects/#{project.slug}/launch_details/#{activity_id}")

      response = json_response(conn, 200)

      # Test that the response has the expected top-level structure
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "launch_params")
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "deep_linking_enabled")
      assert Map.has_key?(response, "can_configure_tool")

      # Test that status is at the top level
      refute Map.has_key?(response["launch_params"], "status")
      assert response["status"] != nil

      # Test that launch_params contains expected LTI parameters
      launch_params = response["launch_params"]
      assert Map.has_key?(launch_params, "iss")
      assert Map.has_key?(launch_params, "login_hint")
      assert Map.has_key?(launch_params, "client_id")
      assert Map.has_key?(launch_params, "target_link_uri")
      assert Map.has_key?(launch_params, "login_url")
    end

    test "API response structure matches frontend component expectations for delivery", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      conn = get(conn, ~p"/api/v1/lti/sections/#{section.slug}/launch_details/#{activity_id}")

      response = json_response(conn, 200)

      # Test that the response has the expected top-level structure
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "launch_params")
      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "deep_linking_enabled")
      assert Map.has_key?(response, "deep_link")
      assert Map.has_key?(response, "can_configure_tool")

      # Test that status is at the top level
      refute Map.has_key?(response["launch_params"], "status")
      assert response["status"] != nil

      # Test that launch_params contains expected LTI parameters
      launch_params = response["launch_params"]
      assert Map.has_key?(launch_params, "iss")
      assert Map.has_key?(launch_params, "login_hint")
      assert Map.has_key?(launch_params, "client_id")
      assert Map.has_key?(launch_params, "target_link_uri")
      assert Map.has_key?(launch_params, "login_url")
    end

    test "deep linking launch details matches frontend component expectations", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      conn =
        get(
          conn,
          ~p"/api/v1/lti/sections/#{section.slug}/deep_linking_launch_details/#{activity_id}"
        )

      response = json_response(conn, 200)

      # Test that the response has the expected structure
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "launch_params")
      assert Map.has_key?(response, "status")

      # Test that status is at the top level (consistent with regular launch details)
      refute Map.has_key?(response["launch_params"], "status")
      assert response["status"] != nil

      # Test that launch_params contains expected LTI parameters for deep linking
      launch_params = response["launch_params"]
      assert Map.has_key?(launch_params, "iss")
      assert Map.has_key?(launch_params, "login_hint")
      assert Map.has_key?(launch_params, "client_id")
      assert Map.has_key?(launch_params, "target_link_uri")
      assert Map.has_key?(launch_params, "login_url")
      assert Map.has_key?(launch_params, "lti_message_type")
      assert launch_params["lti_message_type"] == "LtiDeepLinkingRequest"
    end
  end

  defp create_lti_external_tool_activity() do
    # Use unique client_id to avoid conflicts
    unique_id = UUID.uuid4()

    attrs = %{
      "client_id" => "integration_test_client_#{unique_id}",
      "custom_params" => "some custom_params",
      "description" => "some description",
      "keyset_url" => "some keyset_url",
      "login_url" => "some login_url",
      "name" => "Integration Test Tool #{unique_id}",
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
