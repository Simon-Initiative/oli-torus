defmodule OliWeb.LegacySuperactivityControllerTest do
  use OliWeb.ConnCase

  import Mox

  alias Oli.Delivery.Sections
  alias Oli.Interop.CustomActivities.Package
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

    test "exports an embedded activity package zip", %{
      conn: conn,
      author: author,
      content: content
    } do
      model =
        content
        |> Map.put("resourceBase", "bundles/export-bundle")
        |> Map.put(
          "modelXml",
          """
          <embed_activity>
            <source>/super_media/bundles/export-bundle/webcontent/custom_activity/customactivity.js</source>
            <assets>
              <asset name="styles">/media/bundles/export-bundle/webcontent/custom_activity/styles.css?v=1</asset>
            </assets>
          </embed_activity>
          """
        )

      expect(Oli.Test.MockAws, :request, 2, fn %ExAws.Operation.S3{} = op ->
        case {op.http_method, op.path} do
          {:get, "media/bundles/export-bundle/webcontent/custom_activity/customactivity.js"} ->
            {:ok, %{status_code: 200, body: "console.log('boot');"}}

          {:get, "media/bundles/export-bundle/webcontent/custom_activity/styles.css"} ->
            {:ok, %{status_code: 200, body: "body { color: red; }"}}
        end
      end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn = post(conn, "/api/v1/superactivity/package/export", %{"model" => model})

      [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "embedded_activity_package.zip"

      entries =
        unzip_to_memory(conn.resp_body)
        |> Enum.into(%{}, fn {name, data} -> {List.to_string(name), data} end)

      assert Map.has_key?(entries, "model.json")
      assert Map.has_key?(entries, "manifest.xml")
      assert entries["manifest.xml"] == model["modelXml"]
      assert entries["webcontent/custom_activity/customactivity.js"] == "console.log('boot');"
      assert entries["webcontent/custom_activity/styles.css"] == "body { color: red; }"
      refute Map.has_key?(entries, "webcontent/custom_activity/unused.json")

      assert Jason.decode!(entries["model.json"]) == %{
               "activityType" => "oli_embedded",
               "authoring" => content["authoring"],
               "base" => "embedded",
               "bibrefs" => [],
               "manifestXmlFile" => "manifest.xml",
               "src" => "index.html",
               "stem" => content["stem"],
               "supportingFilesPath" => "webcontent/",
               "title" => "Embedded activity",
               "version" => 1
             }
    end

    test "exports supporting files referenced by ctat-style manifest xml", %{
      conn: conn,
      author: author,
      content: content
    } do
      model =
        content
        |> Map.put("resourceBase", "bundles/export-bundle")
        |> Map.put(
          "modelXml",
          """
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE ctat PUBLIC "-//Carnegie Mellon University//DTD CTAT 1.1//EN" "http://oli.cmu.edu/dtd/cmu-ctat-tutor_1.1.dtd">
          <ctat id="PopGenHWEseq_class" width="1000" height="700" max_attempts="-1">
            <title>Population Genetics - Hardy-Weinberg Equilibrium (4 problems)</title>
            <interface>webcontent/PopGenHWE/sequence.xml</interface>
            <dataset package="null" />
            <asset>webcontent/PopGenHWE/HTML/PopulationGenetics2.html</asset>
          </ctat>
          """
        )

      expect(Oli.Test.MockAws, :request, 2, fn %ExAws.Operation.S3{} = op ->
        case {op.http_method, op.path} do
          {:get, "media/bundles/export-bundle/webcontent/PopGenHWE/sequence.xml"} ->
            {:ok, %{status_code: 200, body: "<sequence />"}}

          {:get, "media/bundles/export-bundle/webcontent/PopGenHWE/HTML/PopulationGenetics2.html"} ->
            {:ok, %{status_code: 200, body: "<html>CTAT</html>"}}
        end
      end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn = post(conn, "/api/v1/superactivity/package/export", %{"model" => model})

      entries =
        unzip_to_memory(conn.resp_body)
        |> Enum.into(%{}, fn {name, data} -> {List.to_string(name), data} end)

      assert entries["webcontent/PopGenHWE/sequence.xml"] == "<sequence />"
      assert entries["webcontent/PopGenHWE/HTML/PopulationGenetics2.html"] == "<html>CTAT</html>"
      refute Map.has_key?(entries, "webcontent/PopGenHWE/unused.json")
    end

    test "imports an embedded activity package zip", %{conn: conn, author: author} do
      existing_resource_base = "bundles/existing-embedded-activity"

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{
                 "parts" => [
                   %{
                     "id" => "part-1",
                     "hints" => [],
                     "responses" => [],
                     "scoringStrategy" => "average"
                   }
                 ],
                 "previewText" => ""
               },
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             "<embed_activity><source>webcontent/custom_activity/app.js</source></embed_activity>"},
            {~c"webcontent/custom_activity/app.js", "console.log('imported');"},
            {~c"webcontent/custom_activity/styles.css", "body { color: blue; }"}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      expect_staged_import_without_existing_objects(2)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => existing_resource_base,
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert %{
               "type" => "success",
               "model" => %{
                 "base" => "embedded",
                 "src" => "index.html",
                 "title" => "Imported Embedded Activity",
                 "modelXml" =>
                   "<embed_activity><source>webcontent/custom_activity/app.js</source></embed_activity>",
                 "resourceBase" => ^existing_resource_base,
                 "resourceURLs" => resource_urls,
                 "resourceVerification" => %{},
                 "authoring" => %{"parts" => [%{"id" => "part-1"}], "previewText" => ""},
                 "stem" => %{"id" => "stem-id", "content" => []},
                 "bibrefs" => []
               }
             } = json_response(conn, 200)

      assert length(resource_urls) == 2

      assert Enum.all?(
               resource_urls,
               &String.contains?(&1, "/media/#{existing_resource_base}/webcontent/")
             )
    end

    test "imports an embedded activity package zip wrapped in a single root directory", %{
      conn: conn,
      author: author
    } do
      existing_resource_base = "bundles/existing-embedded-activity"

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"embedded_activity_package/model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{
                 "parts" => [
                   %{
                     "id" => "part-1",
                     "hints" => [],
                     "responses" => [],
                     "scoringStrategy" => "average"
                   }
                 ],
                 "previewText" => ""
               },
               "bibrefs" => []
             })},
            {~c"embedded_activity_package/manifest.xml",
             "<embed_activity><source>webcontent/custom_activity/app.js</source></embed_activity>"},
            {~c"embedded_activity_package/webcontent/custom_activity/app.js",
             "console.log('imported');"},
            {~c"embedded_activity_package/webcontent/custom_activity/styles.css",
             "body { color: blue; }"}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      expect_staged_import_without_existing_objects(2)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => existing_resource_base,
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert %{
               "type" => "success",
               "model" => %{
                 "resourceBase" => ^existing_resource_base,
                 "resourceURLs" => resource_urls
               }
             } = json_response(conn, 200)

      assert length(resource_urls) == 2
    end

    test "imports every file in the webcontent tree into the current activity bundle", %{
      conn: conn,
      author: author
    } do
      existing_resource_base = "bundles/existing-embedded-activity"

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             """
             <embed_activity>
               <source>webcontent/custom_activity/app.js</source>
               <assets>
                 <asset name="styles">webcontent/custom_activity/styles/main.css</asset>
                 <asset name="image">webcontent/custom_activity/assets/images/hero.png</asset>
                 <asset name="data">webcontent/custom_activity/assets/data/config.json</asset>
               </assets>
             </embed_activity>
             """},
            {~c"webcontent/custom_activity/app.js", "console.log('imported');"},
            {~c"webcontent/custom_activity/styles/main.css", "body { color: blue; }"},
            {~c"webcontent/custom_activity/assets/images/hero.png", "png-binary"},
            {~c"webcontent/custom_activity/assets/data/config.json", ~s({"ok":true})}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      promoted_paths = Agent.start_link(fn -> [] end)
      {:ok, promoted_paths} = promoted_paths

      expect_staged_import_without_existing_objects(4, promoted_paths)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => existing_resource_base,
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert %{
               "type" => "success",
               "model" => %{
                 "resourceBase" => ^existing_resource_base,
                 "resourceURLs" => resource_urls
               }
             } = json_response(conn, 200)

      assert length(resource_urls) == 4

      assert Enum.sort(Agent.get(promoted_paths, & &1)) == [
               "media/#{existing_resource_base}/webcontent/custom_activity/app.js",
               "media/#{existing_resource_base}/webcontent/custom_activity/assets/data/config.json",
               "media/#{existing_resource_base}/webcontent/custom_activity/assets/images/hero.png",
               "media/#{existing_resource_base}/webcontent/custom_activity/styles/main.css"
             ]
    end

    test "rolls back promoted files when promotion fails partway through import", %{
      conn: conn,
      author: author
    } do
      existing_resource_base = "bundles/existing-embedded-activity"

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             """
             <embed_activity>
               <source>webcontent/custom_activity/app.js</source>
               <assets>
                 <asset name="styles">webcontent/custom_activity/styles.css</asset>
               </assets>
             </embed_activity>
             """},
            {~c"webcontent/custom_activity/app.js", "console.log('imported');"},
            {~c"webcontent/custom_activity/styles.css", "body { color: blue; }"}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      operations = Agent.start_link(fn -> [] end)
      {:ok, operations} = operations
      existing_app_js = "media/#{existing_resource_base}/webcontent/custom_activity/app.js"

      expected_destination_key =
        "media/#{existing_resource_base}/webcontent/custom_activity/styles.css"

      existing_styles_css =
        "media/#{existing_resource_base}/webcontent/custom_activity/styles.css"

      expect(Oli.Test.MockAws, :request, 11, fn %ExAws.Operation.S3{} = op ->
        normalized_path = normalize_s3_path(op.path)
        Agent.update(operations, &[{op.http_method, normalized_path, op.headers, op.params} | &1])

        cond do
          op.http_method == :put and Map.has_key?(op.headers, "cache-control") ->
            assert String.contains?(normalized_path, "/.import-staging/")
            {:ok, %{status_code: 200}}

          op.http_method == :get ->
            case op.params["prefix"] do
              ^existing_app_js ->
                {:ok,
                 %{
                   status_code: 200,
                   body: %{
                     contents: [%{key: existing_app_js}]
                   }
                 }}

              ^existing_styles_css ->
                {:ok, %{status_code: 200, body: %{contents: []}}}
            end

          op.http_method == :put and Map.has_key?(op.headers, "x-amz-copy-source") ->
            copy_source = op.headers["x-amz-copy-source"]

            cond do
              String.contains?(copy_source, "/.import-backup/") ->
                {:ok, %{status_code: 200}}

              String.contains?(copy_source, "/.import-staging/") and
                  String.ends_with?(normalized_path, "/webcontent/custom_activity/app.js") ->
                {:ok, %{status_code: 200}}

              String.contains?(copy_source, "/.import-staging/") and
                  String.ends_with?(normalized_path, "/webcontent/custom_activity/styles.css") ->
                {:error, :copy_failed}

              true ->
                {:ok, %{status_code: 200}}
            end

          op.http_method == :delete ->
            {:ok, %{status_code: 204}}
        end
      end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => existing_resource_base,
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert %{
               "type" => "error",
               "result" => "failure",
               "code" => "supporting_file_promote_failed",
               "message" => "The staged package could not be promoted into the activity bundle.",
               "details" => %{
                 "reason" => %{
                   "code" => "promote_copy_failed",
                   "destination_key" => ^expected_destination_key,
                   "staged_key" => staged_key
                 }
               }
             } = json_response(conn, 400)

      assert String.contains?(staged_key, "/.import-staging/")

      recorded_operations =
        operations
        |> Agent.get(&Enum.reverse(&1))

      assert Enum.any?(recorded_operations, fn {method, path, headers, _params} ->
               method == :put and
                 path == "/media/#{existing_resource_base}/webcontent/custom_activity/app.js" and
                 String.contains?(headers["x-amz-copy-source"] || "", "/.import-staging/")
             end)

      assert Enum.any?(recorded_operations, fn {method, path, headers, _params} ->
               method == :put and
                 path == "/media/#{existing_resource_base}/webcontent/custom_activity/app.js" and
                 String.contains?(headers["x-amz-copy-source"] || "", "/.import-backup/")
             end)

      assert Enum.any?(recorded_operations, fn {method, path, _headers, _params} ->
               method == :delete and String.contains?(path, "/.import-staging/")
             end)
    end

    test "rejects a package when the manifest references files missing from the archive", %{
      conn: conn,
      author: author
    } do
      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             """
             <embed_activity>
               <source>webcontent/custom_activity/app.js</source>
               <assets>
                 <asset name="styles">webcontent/custom_activity/styles.css</asset>
               </assets>
             </embed_activity>
             """},
            {~c"webcontent/custom_activity/app.js", "console.log('imported');"}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => "bundles/existing-embedded-activity",
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert json_response(conn, 400) == %{
               "type" => "error",
               "result" => "failure",
               "code" => "missing_referenced_files",
               "message" =>
                 "The package manifest references files that are missing from the ZIP archive.",
               "details" => %{
                 "missing_files" => ["webcontent/custom_activity/styles.css"]
               }
             }
    end

    test "rejects a package when the archive contains too many files", %{
      conn: conn,
      author: author
    } do
      previous_limits = Application.get_env(:oli, Package, [])

      Application.put_env(
        :oli,
        Package,
        Keyword.merge(previous_limits,
          max_archive_file_count: 2,
          max_archive_uncompressed_bytes: 50_000,
          max_archive_entry_bytes: 50_000
        )
      )

      on_exit(fn -> Application.put_env(:oli, Package, previous_limits) end)

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             "<embed_activity><source>webcontent/custom_activity/app.js</source></embed_activity>"},
            {~c"webcontent/custom_activity/app.js", "console.log('imported');"}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => "bundles/existing-embedded-activity",
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert json_response(conn, 400) == %{
               "type" => "error",
               "result" => "failure",
               "code" => "archive_file_count_exceeded",
               "message" => "The ZIP archive contains too many files.",
               "details" => %{"actual_file_count" => 3, "max_file_count" => 2}
             }
    end

    test "rejects a package when an archive entry exceeds the size limit", %{
      conn: conn,
      author: author
    } do
      previous_limits = Application.get_env(:oli, Package, [])

      Application.put_env(
        :oli,
        Package,
        Keyword.merge(previous_limits,
          max_archive_file_count: 50,
          max_archive_uncompressed_bytes: 50_000,
          max_archive_entry_bytes: 1_000
        )
      )

      on_exit(fn -> Application.put_env(:oli, Package, previous_limits) end)

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             "<embed_activity><source>webcontent/custom_activity/app.js</source></embed_activity>"},
            {~c"webcontent/custom_activity/app.js", String.duplicate("x", 1_001)}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => "bundles/existing-embedded-activity",
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert json_response(conn, 400) == %{
               "type" => "error",
               "result" => "failure",
               "code" => "archive_entry_too_large",
               "message" => "A file in the ZIP archive exceeds the allowed size.",
               "details" => %{
                 "path" => "webcontent/custom_activity/app.js",
                 "actual_bytes" => 1001,
                 "max_bytes" => 1000
               }
             }
    end

    test "rejects a package when total uncompressed archive size exceeds the limit", %{
      conn: conn,
      author: author
    } do
      previous_limits = Application.get_env(:oli, Package, [])

      Application.put_env(
        :oli,
        Package,
        Keyword.merge(previous_limits,
          max_archive_file_count: 50,
          max_archive_uncompressed_bytes: 1_500,
          max_archive_entry_bytes: 1_000
        )
      )

      on_exit(fn -> Application.put_env(:oli, Package, previous_limits) end)

      zip_binary =
        Oli.Utils.zip(
          [
            {~c"model.json",
             Jason.encode!(%{
               "version" => 1,
               "activityType" => "oli_embedded",
               "base" => "embedded",
               "src" => "index.html",
               "manifestXmlFile" => "manifest.xml",
               "supportingFilesPath" => "webcontent/",
               "title" => "Imported Embedded Activity",
               "stem" => %{"id" => "stem-id", "content" => []},
               "authoring" => %{"parts" => [], "previewText" => ""},
               "bibrefs" => []
             })},
            {~c"manifest.xml",
             """
             <embed_activity>
               <source>webcontent/custom_activity/app.js</source>
               <assets>
                 <asset name="styles">webcontent/custom_activity/styles.css</asset>
               </assets>
             </embed_activity>
             """},
            {~c"webcontent/custom_activity/app.js", String.duplicate("a", 700)},
            {~c"webcontent/custom_activity/styles.css", String.duplicate("b", 700)}
          ],
          "embedded_activity_package.zip"
        )

      upload_path =
        Path.join(
          System.tmp_dir!(),
          "embedded_activity_package_#{System.unique_integer([:positive])}.zip"
        )

      File.write!(upload_path, zip_binary)
      on_exit(fn -> File.rm_rf(upload_path) end)

      conn =
        recycle(conn)
        |> log_in_author(author)

      conn =
        post(conn, "/api/v1/superactivity/package/import", %{
          "resourceBase" => "bundles/existing-embedded-activity",
          "upload" => %Plug.Upload{
            content_type: "application/zip",
            filename: "embedded_activity_package.zip",
            path: upload_path
          }
        })

      assert json_response(conn, 400) == %{
               "type" => "error",
               "result" => "failure",
               "code" => "archive_uncompressed_size_exceeded",
               "message" => "The ZIP archive is too large when uncompressed.",
               "details" => %{"actual_bytes" => 1860, "max_bytes" => 1500}
             }
    end
  end

  defp expect_staged_import_without_existing_objects(file_count, promoted_paths \\ nil) do
    expect(Oli.Test.MockAws, :request, file_count * 4, fn %ExAws.Operation.S3{} = op ->
      normalized_path = normalize_s3_path(op.path)

      cond do
        op.http_method == :put and Map.has_key?(op.headers, "cache-control") ->
          assert String.contains?(normalized_path, "/.import-staging/")
          assert op.headers["cache-control"] == "no-cache, no-store, must-revalidate"
          {:ok, %{status_code: 200}}

        op.http_method == :get ->
          assert op.path == "/"
          assert String.starts_with?(op.params["prefix"], "media/bundles/")
          refute String.contains?(op.params["prefix"], ".import-")
          {:ok, %{status_code: 200, body: %{contents: []}}}

        op.http_method == :put and Map.has_key?(op.headers, "x-amz-copy-source") ->
          assert String.contains?(op.headers["x-amz-copy-source"], "/.import-staging/")

          if promoted_paths do
            Agent.update(promoted_paths, &[String.trim_leading(normalized_path, "/") | &1])
          end

          {:ok, %{status_code: 200}}

        op.http_method == :delete ->
          assert String.contains?(normalized_path, "/.import-staging/")
          {:ok, %{status_code: 204}}
      end
    end)
  end

  defp normalize_s3_path(path), do: "/" <> String.trim_leading(path, "/")

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
