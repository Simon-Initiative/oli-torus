defmodule OliWeb.LegacySuperactivityControllerTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Seeder

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Activities

  alias OliWeb.Router.Helpers, as: Routes

  describe "legacy superactivity" do
    setup [:setup_session]

    @tag :skip
    # this test should be migrated to a liveview approach since now we
    # are not rendering any content on the first response (we render when websocket is connected)
    test "deliver legacy superactivity", %{
      user: user,
      conn: conn,
      section: section,
      page_revision: page_revision,
      activity_id: activity_id
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      ensure_user_visit(user, section)

      instructor =
        user_fixture(%{
          name: "Mr John Bay Doe",
          given_name: "John",
          family_name: "Doe",
          middle_name: "Bay"
        })

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      Activities.list_activity_registrations()

      conn = get(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")

      activity_attempt = Attempts.get_activity_attempt_by(resource_id: activity_id)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        get(conn, Routes.legacy_superactivity_path(conn, :context, activity_attempt.attempt_guid))

      assert conn.resp_body =~ ~s("mode":"delivery")

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadClientConfig",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<super_activity_client server_time_zone=)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "beginSession",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<super_activity_session>)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadContentFile",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<embed_activity id="custom_side" width="670" height="300">)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "startAttempt",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<attempt_history max_attempts=)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "writeFileRecord",
              "activityContextGuid" => activity_attempt.attempt_guid,
              "byteEncoding" => "utf8",
              "fileName" => "custom_file.xml",
              "fileRecordData" => """
                <launch_attributes>
                <attribute attribute_id="height" value="300"/>
                <attribute attribute_id="width" value="670"/>
                </launch_attributes>
              """,
              "resourceTypeID" => "oli_embedded",
              "mimeType" => "xml",
              "userGuid" => user.id,
              "attemptNumber" => 1
            }
          )
        )

      assert conn.resp_body =~ ~s(<file_record file_name=")

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadFileRecord",
              "activityContextGuid" => activity_attempt.attempt_guid,
              "fileName" => "custom_file.xml",
              "userGuid" => user.id,
              "attemptNumber" => 1
            }
          )
        )

      assert conn.resp_body =~ ~s(<launch_attributes>)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "scoreAttempt",
              "activityContextGuid" => activity_attempt.attempt_guid,
              "scoreValue" => "2",
              "scoreId" => "percent"
            }
          )
        )

      assert conn.resp_body =~ ~s(<attempt_history max_attempts=)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "endAttempt",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<attempt_history max_attempts=)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "none",
              "activityContextGuid" => activity_attempt.attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(command not supported)
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "src" => "index.html",
      "base" => "oli_embedded",
      "stem" => %{
        "id" => "1531714844",
        "content" => [
          %{
            "id" => "2857256760",
            "type" => "p",
            "children" => [
              %{
                "text" => ""
              }
            ]
          }
        ]
      },
      "title" => "Embedded activity",
      "modelXml" => ~s(<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE embed_activity PUBLIC "-//Carnegie Mellon University//DTD Embed 1.1//EN" "http://oli.cmu.edu/dtd/oli-embed-activity_1.0.dtd">
      <embed_activity id="custom_side" width="670" height="300">
        <title>Custom Activity</title>
        <source>webcontent/custom_activity/customactivity.js</source>
        <assets>
          <asset name="layout">webcontent/custom_activity/layout.html</asset>
          <asset name="controls">webcontent/custom_activity/controls.html</asset>
          <asset name="styles">webcontent/custom_activity/styles.css</asset>
          <asset name="questions">webcontent/custom_activity/questions.xml</asset>
        </assets>
      </embed_activity>
      ),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1431162465",
            "hints" => [],
            "responses" => [],
            "scoringStrategy" => "average"
          }
        ],
        "previewText" => ""
      },
      "resourceBase" => "4083472489",
      "resourceURLs" => []
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(
        %{title: "one", max_attempts: 2, content: content},
        :publication,
        :project,
        :author,
        :activity,
        Activities.get_registration_by_slug("oli_embedded").id
      )

    attrs = %{
      graded: false,
      max_attempts: 1,
      title: "page1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "purpose" => "None",
            "activity_id" => Map.get(map, :activity).resource.id
          }
        ]
      },
      objectives: %{
        "attached" => [Map.get(map, :o1).resource.id]
      }
    }

    map = Seeder.add_page(map, attrs, :page)

    {:ok, publication} =
      Oli.Publishing.publish_project(map.project, "some changes", map.author.id)

    map = Map.put(map, :publication, publication)

    map =
      map
      |> Seeder.create_section()
      |> Seeder.create_section_resources()

    lti_params_id =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(
        ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
        map.section.context_id
      )
      |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> OliWeb.Common.LtiSession.put_session_lti_params(lti_params_id)

    {
      :ok,
      conn: conn,
      map: map,
      author: map.author,
      institution: map.institution,
      user: user,
      project: map.project,
      publication: map.publication,
      section: map.section,
      revision: map.revision1,
      page_revision: map.page.revision,
      activity_id: Map.get(map, :activity).resource.id
    }
  end
end
