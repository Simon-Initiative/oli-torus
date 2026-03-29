defmodule OliWeb.LegacySuperactivityControllerTest do
  use OliWeb.ConnCase

  import Mox

  alias Oli.Delivery.Sections
  alias Oli.Seeder

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Activities

  alias OliWeb.Router.Helpers, as: Routes

  describe "legacy superactivity" do
    setup :verify_on_exit!
    setup [:setup_session]

    # this test should be migrated to a liveview approach since now we
    # are not rendering any content on the first response (we render when websocket is connected)
    @tag :skip
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
        |> log_in_user(user)

      conn =
        get(conn, Routes.legacy_superactivity_path(conn, :context, activity_attempt.attempt_guid))

      assert conn.resp_body =~ ~s("mode":"delivery")

      conn =
        recycle(conn)
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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
        |> log_in_user(user)

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

    test "creates and services an embedded preview session", %{
      conn: conn,
      content: content,
      activity_id: activity_id,
      project: project,
      author: author,
      user: user
    } do
      preview_attempt_guid = Ecto.UUID.generate()

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(conn, :preview_context),
          %{
            "attemptGuid" => preview_attempt_guid,
            "model" => content,
            "context" => %{
              "projectSlug" => project.slug,
              "pageTitle" => "Preview page",
              "resourceId" => activity_id,
              "graded" => false
            }
          }
        )

      assert conn.resp_body =~ preview_attempt_guid

      assert conn.resp_body =~
               ~s("server_url":"https://www.example.com/jcourse/superactivity/server")

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "beginSession",
              "activityContextGuid" => preview_attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<super_activity_session>)
      assert conn.resp_body =~ ~s(scoring_mode="total")
      assert conn.resp_body =~ ~s(title="Embedded activity")

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadClientConfig",
              "activityContextGuid" => preview_attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<super_activity_client server_time_zone=)

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadContentFile",
              "activityContextGuid" => preview_attempt_guid
            }
          )
        )

      assert conn.resp_body =~ ~s(<embed_activity id="custom_side" width="670" height="300">)

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "writeFileRecord",
              "activityContextGuid" => preview_attempt_guid,
              "byteEncoding" => "utf8",
              "fileName" => "preview.xml",
              "fileRecordData" => "<preview />",
              "resourceTypeID" => "oli_embedded",
              "mimeType" => "xml",
              "userGuid" => user.id,
              "attemptNumber" => 1
            }
          )
        )

      assert conn.resp_body =~ ~s(<file_record file_name="preview.xml")

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "loadFileRecord",
              "activityContextGuid" => preview_attempt_guid,
              "fileName" => "preview.xml",
              "attemptNumber" => 1
            }
          )
        )

      assert conn.resp_body == "<preview />"

      conn =
        recycle(conn)
        |> log_in_author(author)
        |> log_in_user(user)

      conn =
        post(
          conn,
          Routes.legacy_superactivity_path(
            conn,
            :process,
            %{
              "commandName" => "scoreAttempt",
              "activityContextGuid" => preview_attempt_guid,
              "scoreValue" => "0.75",
              "scoreId" => "percent"
            }
          )
        )

      assert conn.resp_body =~ ~s(<attempt_history)
      assert conn.resp_body =~ ~s(<score value="75.0" score_id="percent"/>)
    end

    test "verifies supporting files relative to resourceBase", %{conn: conn, author: author} do
      expect(Oli.Test.MockAws, :request, 2, fn %ExAws.Operation.S3{} = op ->
        assert op.http_method == :get
        send(self(), {:aws_verify_request, op.params["prefix"]})

        case op.params["prefix"] do
          "media/bundles/verified-bundle/webcontent/custom_activity/customactivity.js" ->
            {:ok,
             %{
               status_code: 200,
               body: %{
                 contents: [
                   %{
                     key:
                       "media/bundles/verified-bundle/webcontent/custom_activity/customactivity.js"
                   }
                 ]
               }
             }}

          "media/bundles/verified-bundle/webcontent/custom_activity/missing.css" ->
            {:ok, %{status_code: 200, body: %{contents: []}}}
        end
      end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/media/verify", %{
          "directory" => "bundles/verified-bundle",
          "references" => [
            "webcontent/custom_activity/customactivity.js",
            "webcontent/custom_activity/missing.css"
          ]
        })

      assert_received {:aws_verify_request,
                       "media/bundles/verified-bundle/webcontent/custom_activity/customactivity.js"}

      assert_received {:aws_verify_request,
                       "media/bundles/verified-bundle/webcontent/custom_activity/missing.css"}

      assert json_response(conn, 200) == %{
               "statuses" => %{
                 "webcontent/custom_activity/customactivity.js" => "verified",
                 "webcontent/custom_activity/missing.css" => "missing"
               }
             }
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    content = %{
      "src" => "index.html",
      "base" => "embedded",
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

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(
      ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
      map.section.context_id
    )
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(map.author)
      |> log_in_user(user)

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
      activity_id: Map.get(map, :activity).resource.id,
      content: content
    }
  end
end
