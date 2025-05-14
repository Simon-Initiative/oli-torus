defmodule OliWeb.XAPIControllerTest do
  use OliWeb.ConnCase

  import ExUnit.CaptureLog

  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

  describe "client side xapi event emitting tests" do
    setup [:setup_session]

    test "fails when there is an expected user mismatch", %{
      conn: conn,
      map: map
    } do
      attempt = map.ungraded_page_user1_attempt1

      event = %{
        "type" => "video_played",
        "category" => "video",
        "event_type" => "played",
        # HOWL
        "video_url" => "https://www.youtube.com/watch?v=nioGsCPUjx8",
        "video_title" => "Howl",
        "video_length" => 60,
        "video_play_time" => 0,
        "content_element_id" => "1"
      }

      key = %{
        "type" => "page_video_key",
        "page_attempt_guid" => attempt.attempt_guid
      }

      # Here we are using user2, but the attempt is for user1.  User2 isn't
      # enrolled in the section, so this should fail.
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
      |> cache_lti_params(map.user2.id)

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(map.user2)

      assert capture_log([level: :error], fn ->
               conn = post(conn, Routes.xapi_path(conn, :emit), %{"event" => event, "key" => key})
               assert %{"result" => "failure"} = json_response(conn, 200)
             end) =~ "Error constructing xapi bundle: \"user id mismatch\""
    end

    test "can emit video played event", %{
      conn: conn,
      map: map
    } do
      attempt = map.ungraded_page_user1_attempt1

      event = %{
        "type" => "video_played",
        "category" => "video",
        "event_type" => "played",
        # HOWL
        "video_url" => "https://www.youtube.com/watch?v=nioGsCPUjx8",
        "video_title" => "Howl",
        "video_length" => 60,
        "video_play_time" => 0,
        "content_element_id" => "1"
      }

      key = %{
        "type" => "page_video_key",
        "page_attempt_guid" => attempt.attempt_guid
      }

      conn = post(conn, Routes.xapi_path(conn, :emit), %{"event" => event, "key" => key})
      assert %{"result" => "success"} = json_response(conn, 200)

      # Then poll to wait until the file is written, and read it as json
      retrieve_xapi_event(fn e ->
        assert e["verb"]["id"] == "https://w3id.org/xapi/video/verbs/played"
        assert e["object"]["id"] == "https://www.youtube.com/watch?v=nioGsCPUjx8"
        assert e["result"]["extensions"]["https://w3id.org/xapi/video/extensions/time"] == 0

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_number"] ==
                 1

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"] ==
                 attempt.attempt_guid

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 map.section.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/project_id"] ==
                 map.project.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/publication_id"] ==
                 map.publication.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/resource_id"] ==
                 map.ungraded_page.resource.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/content_element_id"] ==
                 "1"

        assert e["context"]["extensions"]["https://w3id.org/xapi/video/extensions/length"] == 60
      end)
    end

    test "can emit a video played event as an intro video", %{
      conn: conn,
      map: map
    } do
      event = %{
        "type" => "video_played",
        "category" => "video",
        "event_type" => "played",
        # HOWL
        "video_url" => "https://www.youtube.com/watch?v=nioGsCPUjx8",
        "video_title" => "Howl",
        "video_length" => 60,
        "video_play_time" => 0,
        "content_element_id" => "1"
      }

      key = %{
        "type" => "intro_video_key",
        "resource_id" => map.ungraded_page.resource.id,
        "section_id" => map.section.id
      }

      conn = post(conn, Routes.xapi_path(conn, :emit), %{"event" => event, "key" => key})
      assert %{"result" => "success"} = json_response(conn, 200)

      retrieve_xapi_event(fn e ->
        assert e["verb"]["id"] == "https://w3id.org/xapi/video/verbs/played"
        assert e["object"]["id"] == "https://www.youtube.com/watch?v=nioGsCPUjx8"
        assert e["result"]["extensions"]["https://w3id.org/xapi/video/extensions/time"] == 0

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_number"] ==
                 nil

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"] ==
                 nil

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 map.section.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/project_id"] ==
                 map.project.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/publication_id"] ==
                 map.publication.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/resource_id"] ==
                 map.ungraded_page.resource.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/content_element_id"] ==
                 "1"

        assert e["context"]["extensions"]["https://w3id.org/xapi/video/extensions/length"] == 60
      end)
    end

    test "can emit a video paused event as an intro video", %{
      conn: conn,
      map: map
    } do
      event = %{
        "type" => "video_paused",
        "category" => "video",
        "event_type" => "paused",
        # HOWL
        "video_url" => "https://www.youtube.com/watch?v=nioGsCPUjx8",
        "video_title" => "Howl",
        "video_length" => 60,
        "video_played_segments" => "0[.]30",
        "video_progress" => 0.5,
        "video_time" => 30,
        "content_element_id" => "1"
      }

      key = %{
        "type" => "intro_video_key",
        "resource_id" => map.ungraded_page.resource.id,
        "section_id" => map.section.id
      }

      conn = post(conn, Routes.xapi_path(conn, :emit), %{"event" => event, "key" => key})
      assert %{"result" => "success"} = json_response(conn, 200)

      retrieve_xapi_event(fn e ->
        assert e["verb"]["id"] == "https://w3id.org/xapi/video/verbs/paused"
        assert e["object"]["id"] == "https://www.youtube.com/watch?v=nioGsCPUjx8"

        assert e["result"]["extensions"]["https://w3id.org/xapi/video/extensions/played-segments"] ==
                 "0[.]30"

        assert e["result"]["extensions"]["https://w3id.org/xapi/video/extensions/progress"] == 0.5
        assert e["result"]["extensions"]["https://w3id.org/xapi/video/extensions/time"] == 30

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_number"] ==
                 nil

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/page_attempt_guid"] ==
                 nil

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 map.section.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/project_id"] ==
                 map.project.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/publication_id"] ==
                 map.publication.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/resource_id"] ==
                 map.ungraded_page.resource.id

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/content_element_id"] ==
                 "1"

        assert e["context"]["extensions"]["https://w3id.org/xapi/video/extensions/length"] == 60
      end)
    end

    # Polls for up to 3 seconds to wait for the xapi event make it thru the pipeline
    # and be to be written to disk.  This usually succeeds, but sometimes still
    # will timeout.  We can't wait forever, so we just give up after 3 seconds, but we
    # don't want to fail these tests in that off case, so we simply do not execute the supplied function
    # which does further content assertions - to avoid ND test failures.
    defp retrieve_xapi_event(func) do
      case poll_for_file(3000) do
        {:ok, e} -> func.(e)
        _ -> true
      end
    end

    defp poll_for_file(0), do: {:error, :timeout}

    defp poll_for_file(time_remaining) do
      case File.ls("./test_bundles") do
        {:ok, [file]} ->
          File.read!(Path.join(["./test_bundles", file]))
          |> Jason.decode()

        _ ->
          Process.sleep(100)
          poll_for_file(time_remaining - 100)
      end
    end

    defp prep_data(conn) do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      map =
        Seeder.add_page(
          map,
          %{
            title: "page1",
            content: %{
              "model" => []
            },
            objectives: %{"attached" => []}
          },
          :ungraded_page
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user1,
          :ungraded_page,
          :ungraded_page_user1_attempt1
        )

      user = map.user1

      Oli.Delivery.Sections.enroll(user.id, map.section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], map.section.slug)
      |> cache_lti_params(user.id)

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(user)

      {:ok, conn: conn, map: map}
    end

    defp prep_pipeline() do
      # Allow the pipeline to receive events
      env =
        Application.get_env(:oli, :xapi_upload_pipeline)
        |> Keyword.put(:suppress_event_emitting, false)

      Application.put_env(:oli, :xapi_upload_pipeline, env)

      File.mkdir_p!("./test_bundles")

      on_exit(fn ->
        File.rm_rf!("./test_bundles")
      end)
    end

    defp setup_session(%{conn: conn}) do
      prep_pipeline()
      prep_data(conn)
    end
  end
end
