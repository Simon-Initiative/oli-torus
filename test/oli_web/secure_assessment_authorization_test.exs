defmodule OliWeb.SecureAssessmentAuthorizationTest do
  use OliWeb.ConnCase, async: true
  import Oli.Factory
  require Phoenix.ChannelTest
  import Phoenix.ChannelTest, only: [subscribe_and_join: 3]
  alias Oli.Accounts
  alias Oli.Delivery.SecureAssessments, as: Policy
  alias Oli.Delivery.SecureAssessments.Scope
  alias OliWeb.Plugs.SecureAssessment, as: Boundary

  setup do
    user = insert(:user)
    section = insert(:section)
    revision = insert(:revision, graded: true)

    sr =
      insert(:section_resource,
        section: section,
        resource_id: revision.resource_id,
        secure_delivery: true
      )

    access = insert(:resource_access, section: section, user: user, resource: revision.resource)
    attempt = insert(:resource_attempt, resource_access: access, revision: revision)
    activity = insert(:activity_attempt, resource_attempt: attempt)
    scope = %Scope{section_id: section.id, resource_id: revision.resource_id}
    normal_token = Accounts.generate_user_session_token(user)
    secure_token = Accounts.generate_user_session_token(user, scope: scope)
    {:ok, normal} = Accounts.get_user_session(normal_token)
    {:ok, secure} = Accounts.get_user_session(secure_token)

    %{
      user: user,
      section: section,
      revision: revision,
      sr: sr,
      attempt: attempt,
      activity: activity,
      scope: scope,
      normal: normal,
      secure: secure,
      normal_token: normal_token,
      secure_token: secure_token
    }
  end

  test "ordinary page and attempt entry requires secure admission", c do
    p = %{"section_slug" => c.section.slug, "revision_slug" => c.revision.slug}

    assert {:error, :secure_launch_required} =
             Boundary.check(c.normal, OliWeb.PageDeliveryController, :page, p)

    assert :ok = Boundary.check(c.secure, OliWeb.PageDeliveryController, :page, p)

    assert {:error, :secure_launch_required} =
             Boundary.check(c.normal, OliWeb.Api.AttemptController, :bulk_retrieve, %{
               "section_slug" => c.section.slug,
               "attemptGuids" => [c.activity.attempt_guid]
             })
  end

  test "parent-attempt model parameters do not unlock unfinished provider adapters", c do
    params = %{
      "section_slug" => c.section.slug,
      "activity_id" => to_string(c.activity.resource_id),
      "activity_attempt_guid" => c.activity.attempt_guid,
      "resource_attempt_guid" => c.attempt.attempt_guid
    }

    assert {:error, _} =
             Boundary.check(c.secure, OliWeb.Api.LtiController, :launch_details, params)

    assert {:error, _} =
             Boundary.check(c.normal, OliWeb.Api.LtiController, :launch_details, params)

    assert {:error, _} =
             Boundary.check(
               c.secure,
               OliWeb.Api.DirectedDiscussionController,
               :index,
               Map.put(params, "resource_id", c.activity.resource_id)
             )
  end

  test "explicit exit is current-token-only, idempotent and does not finish an attempt", c do
    {:ok, ordinary_socket} =
      Phoenix.ChannelTest.connect(OliWeb.UserSocket, %{
        "token" => OliWeb.SecureSocket.sign(OliWeb.Endpoint, c.normal)
      })

    {:ok, _, ordinary_channel} =
      subscribe_and_join(
        ordinary_socket,
        OliWeb.GlobalUserStateChannel,
        "user_global_state:#{c.user.id}"
      )

    other_secure = Accounts.generate_user_session_token(c.user, scope: c.scope)
    {:ok, other} = Accounts.get_user_session(other_secure)
    topic = "secure_session:#{c.secure.token_id}"
    other_topic = "secure_session:#{other.token_id}"
    live_topic = "users_sessions:#{Base.url_encode64(c.secure_token)}"
    OliWeb.Endpoint.subscribe(topic)
    OliWeb.Endpoint.subscribe(other_topic)
    OliWeb.Endpoint.subscribe(live_topic)
    original_attempt = Oli.Repo.reload!(c.attempt)

    conn =
      c.conn
      |> init_test_session(%{user_token: c.secure_token, user_live_socket_id: live_topic})
      |> post("/secure-assessment/exit", %{return_to: "/sections/anything"})

    assert redirected_to(conn) == "/secure-assessment/signed-out"
    refute get_session(conn, :user_token)
    assert {:error, :unauthenticated} = Accounts.get_user_session(c.secure_token)
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}
    assert_receive %Phoenix.Socket.Broadcast{topic: ^live_topic, event: "disconnect"}
    refute_receive %Phoenix.Socket.Broadcast{topic: ^other_topic, event: "disconnect"}
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(c.normal_token)
    assert Process.alive?(ordinary_channel.channel_pid)
    assert OliWeb.SecureSocket.channel_allowed?(ordinary_channel, ordinary_channel.topic)
    assert {:ok, _} = Accounts.get_user_session(other_secure)
    assert Oli.Repo.reload!(c.attempt) == original_attempt
    repeated = recycle(conn) |> post("/secure-assessment/exit")
    assert redirected_to(repeated) == "/secure-assessment/signed-out"
    body = recycle(repeated) |> get("/secure-assessment/signed-out") |> html_response(200)
    assert body =~ "Assessment session ended"
    refute body =~ Base.url_encode64(c.secure_token)
  end

  test "exit after finalization leaves result unchanged and ordinary logout cannot choose a secure return target",
       c do
    attempt =
      c.attempt
      |> Ecto.Changeset.change(lifecycle_state: :evaluated)
      |> Oli.Repo.update!()
      |> Oli.Repo.reload!()

    conn =
      c.conn
      |> init_test_session(%{user_token: c.secure_token})
      |> delete("/users/log_out", %{request_path: "/sections/elsewhere"})

    assert redirected_to(conn) == "/secure-assessment/signed-out"
    assert Oli.Repo.reload!(attempt) == attempt
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(c.normal_token)
  end

  test "explicit exit requires CSRF protection", c do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      c.conn
      |> init_test_session(%{user_token: c.secure_token})
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
      |> post("/secure-assessment/exit")
    end

    assert {:ok, _} = Accounts.get_user_session(c.secure_token)
  end

  test "secure installation clears remember-me and ordinary replacement leaves old authority independent",
       c do
    conn =
      c.conn |> init_test_session(%{}) |> OliWeb.UserAuth.install_session(c.user, c.secure_token)

    assert %{max_age: 0} = conn.resp_cookies["_oli_web_user_remember_me"]
    assert get_session(conn, :user_token) == c.secure_token
    ordinary = OliWeb.UserAuth.create_session(conn, c.user)
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(get_session(ordinary, :user_token))
    assert {:ok, %{scope: scope}} = Accounts.get_user_session(c.secure_token)
    assert scope == c.scope
  end

  test "current token only controls confinement, never other ordinary sessions", c do
    assert :ok = Boundary.check(c.normal, OliWeb.PageDeliveryController, :index, %{})

    assert {:error, :secure_resource_mismatch} =
             Boundary.check(c.secure, OliWeb.PageDeliveryController, :index, %{})

    Accounts.delete_user_session_token(c.secure_token)
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(c.normal_token)
    assert {:error, :unauthenticated} = Accounts.get_user_session_by_id(c.secure.token_id)
  end

  test "a simultaneous author cookie does not bypass scoped navigation", c do
    conn =
      c.conn
      |> log_in_author(insert(:author))
      |> put_session(:user_token, c.secure_token)
      |> get("/authors/settings")

    assert html_response(conn, 403) =~ "Assessment access restricted"
    assert {:ok, %{scope: nil}} = Accounts.get_user_session(c.normal_token)
  end

  test "canonical ownership and pinned revision cannot be overridden", c do
    assert {:ok, [target]} = Policy.resolve_attempts(:activity, [c.activity.attempt_guid])
    assert target.revision_id == c.attempt.revision_id
    assert target.activity_revision_id == c.activity.revision_id
    assert {:error, :not_found} = Policy.authorize(c.scope, insert(:user).id, :save, target)

    assert {:error, :not_found} =
             Policy.authorize_batch(c.scope, c.user.id, :save, [target], %{
               resource_attempt_guid: "another-parent"
             })

    assert {:error, :secure_resource_mismatch} =
             Policy.authorize(
               %Scope{section_id: c.section.id, resource_id: insert(:resource).id},
               c.user.id,
               :save,
               target
             )
  end

  test "batch validation rejects missing, duplicate and excessive identifiers", c do
    guid = c.activity.attempt_guid
    assert {:error, :not_found} = Policy.resolve_attempts(:activity, [guid, "unknown"])
    assert {:error, :invalid_batch} = Policy.resolve_attempts(:activity, [guid, guid], true)

    assert {:error, :invalid_batch} =
             Policy.resolve_attempts(:activity, List.duplicate(guid, 101))

    assert {:error, :invalid_batch} = Policy.resolve_attempts(:activity, [nil])
    assert {:ok, [_]} = Policy.resolve_attempts(:activity, [guid, guid])
  end

  test "ordinary finalized review is independent of secure-session existence", c do
    assert {:ok, [target]} = Policy.resolve_attempts(:resource, [c.attempt.attempt_guid])
    assert {:error, :review_not_allowed} = Policy.authorize(nil, c.user.id, :review, target)

    assert {:ok, :review} =
             Policy.authorize(nil, c.user.id, :review, %{target | lifecycle_state: :evaluated})

    assert {:error, :secure_launch_required} =
             Policy.authorize(nil, c.user.id, :save, %{target | lifecycle_state: :evaluated})

    for operation <- [:start, :save, :submit, :dependency_read, :dependency_write] do
      assert {:error, :review_not_allowed} =
               Policy.authorize(c.scope, c.user.id, operation, %{
                 target
                 | lifecycle_state: :evaluated
               })
    end
  end

  test "excluded superactivity routes stay closed to secure sessions", c do
    assert {:error, :secure_resource_mismatch} =
             Boundary.check(c.secure, OliWeb.LegacySuperactivityController, :context, %{
               "attempt_guid" => c.activity.attempt_guid
             })

    assert {:error, :secure_resource_mismatch} =
             Boundary.check(c.secure, OliWeb.LegacySuperactivityController, :process, %{
               "activityContextGuid" => c.activity.attempt_guid,
               "commandName" => "loadContentFile"
             })
  end

  test "capability disablement and removing policy do not broaden a secure token", c do
    assert {:ok, target} = Policy.resolve_page(c.section.slug, c.revision.slug)
    target = %{target | secure_delivery: false, resource_id: insert(:resource).id}

    assert {:error, :secure_resource_mismatch} =
             Policy.authorize(c.scope, c.user.id, :deliver, target)

    assert {:ok, :ordinary_delivery} = Policy.authorize(nil, c.user.id, :deliver, target)
  end

  test "signed socket capability rechecks deletion and does not expose raw token", c do
    signed = OliWeb.SecureSocket.sign(OliWeb.Endpoint, c.secure)
    assert {:ok, %{token_id: id}} = OliWeb.SecureSocket.verify(OliWeb.Endpoint, signed)
    assert id == c.secure.token_id
    refute OliWeb.SecureSocket.unrestricted?(%{assigns: %{user_session: c.secure}})
    ordinary_socket = %{assigns: %{user_session: c.normal}}
    assert OliWeb.SecureSocket.unrestricted?(ordinary_socket)
    Accounts.delete_user_session_token(c.secure_token)
    assert {:error, :unauthenticated} = OliWeb.SecureSocket.verify(OliWeb.Endpoint, signed)
    assert OliWeb.SecureSocket.unrestricted?(ordinary_socket)
    Accounts.delete_user_session_token(c.normal_token)
    refute OliWeb.SecureSocket.unrestricted?(ordinary_socket)
  end

  test "HTTP protected page is denied before delivery context and is not cached", c do
    conn =
      c.conn
      |> init_test_session(%{user_token: c.normal_token})
      |> get("/sections/#{c.section.slug}/page/#{c.revision.slug}")

    assert html_response(conn, 403) =~ "Assessment access restricted"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "a forged review GUID cannot turn delivery or prologue into review", c do
    p = %{
      "section_slug" => c.section.slug,
      "revision_slug" => c.revision.slug,
      "attempt_guid" => c.attempt.attempt_guid
    }

    for view <- [OliWeb.Delivery.Student.PrologueLive, OliWeb.Delivery.Student.LessonLive] do
      assert {:error, :secure_launch_required} = Boundary.check(c.normal, view, :show, p)
    end

    conn =
      c.conn
      |> init_test_session(%{user_token: c.normal_token})
      |> get(
        "/sections/#{c.section.slug}/prologue/#{c.revision.slug}?attempt_guid=#{c.attempt.attempt_guid}"
      )

    assert html_response(conn, 403) =~ "Assessment access restricted"
  end

  test "external tool entry and mixed model batches cannot bypass protected parent", c do
    # Persisted dynamic/pinned attempt membership protects models even before the
    # current publication's related_activities projection contains the activity.
    assert Policy.protected_models?(c.section.slug, [c.activity.resource_id])
    Oli.Repo.update!(Ecto.Changeset.change(c.sr, related_activities: [c.activity.resource_id]))
    p = %{"section_slug" => c.section.slug, "activity_id" => to_string(c.activity.resource_id)}

    assert {:error, :secure_launch_required} =
             Boundary.check(c.normal, OliWeb.Api.LtiController, :launch_details, p)

    assert {:error, :secure_launch_required} =
             Boundary.check(c.normal, OliWeb.Api.ActivityController, :bulk_retrieve_delivery, %{
               "section_slug" => c.section.slug,
               "resourceIds" => [c.activity.resource_id, insert(:resource).id]
             })
  end

  test "mixed part mutation is rejected before changing any response", c do
    part = insert(:part_attempt, activity_attempt: c.activity, response: %{"input" => "original"})
    foreign = insert(:part_attempt)

    conn =
      c.conn
      |> init_test_session(%{user_token: c.secure_token})
      |> patch(
        "/api/v1/state/course/#{c.section.slug}/activity_attempt/#{c.activity.attempt_guid}",
        %{
          "partInputs" => [
            %{"attemptGuid" => part.attempt_guid, "response" => %{"input" => "changed"}},
            %{"attemptGuid" => foreign.attempt_guid, "response" => %{"input" => "changed"}}
          ]
        }
      )

    assert json_response(conn, 404)["error"] == "not_found"
    assert Oli.Repo.reload!(part).response == %{"input" => "original"}
  end

  test "native upload binds the part to its parent and rejects finalized writes", c do
    part = insert(:part_attempt, activity_attempt: c.activity)

    params = %{
      "section_slug" => c.section.slug,
      "activity_attempt_guid" => c.activity.attempt_guid,
      "part_attempt_guid" => part.attempt_guid
    }

    assert :ok = Boundary.check(c.secure, OliWeb.Api.AttemptController, :file_upload, params)

    assert {:error, :not_found} =
             Boundary.check(
               c.secure,
               OliWeb.Api.AttemptController,
               :file_upload,
               Map.put(params, "activity_attempt_guid", "different-parent")
             )

    assert {:error, :secure_launch_required} =
             Boundary.check(c.normal, OliWeb.Api.AttemptController, :file_upload, params)

    Oli.Repo.update!(Ecto.Changeset.change(c.attempt, lifecycle_state: :evaluated))

    assert {:error, :review_not_allowed} =
             Boundary.check(c.secure, OliWeb.Api.AttemptController, :file_upload, params)
  end

  test "connected assessment authorization rechecks deletion and policy", c do
    params = %{"section_slug" => c.section.slug, "revision_slug" => c.revision.slug}

    socket = %Phoenix.LiveView.Socket{
      view: OliWeb.Delivery.Student.LessonLive,
      assigns: %{user_session: c.secure}
    }

    assert :ok = OliWeb.LiveSessionPlugs.SecureAssessment.authorize(socket, params)
    Accounts.delete_user_session_token(c.secure_token)

    assert {:error, :unauthenticated} =
             OliWeb.LiveSessionPlugs.SecureAssessment.authorize(socket, params)

    assert {:ok, %{scope: nil}} = Accounts.get_user_session(c.normal_token)
  end

  test "secure global subscriptions and invalidated delayed/outbound messages are denied", c do
    socket = %Phoenix.Socket{
      topic: "user_global_state:#{c.user.id}",
      assigns: %{user_session: c.secure, user: c.user.sub}
    }

    assert {:error, _} = OliWeb.GlobalUserStateChannel.join(socket.topic, %{}, socket)

    assert {:stop, :normal, _} =
             OliWeb.GlobalUserStateChannel.handle_info({:after_join, "#{c.user.id}"}, socket)

    normal = %{socket | assigns: %{user_session: c.normal, user: c.user.sub}}
    assert OliWeb.SecureSocket.channel_allowed?(normal, normal.topic)
    refute OliWeb.SecureSocket.channel_allowed?(normal, "user_global_state:#{insert(:user).id}")
    Accounts.delete_user_session_token(c.normal_token)

    assert {:stop, :normal, _} =
             OliWeb.GlobalUserStateChannel.handle_info({:delta, %{secret: true}}, normal)
  end

  test "legacy ordinary socket cannot subscribe to protected assessment discussion", c do
    socket = %Phoenix.Socket{assigns: %{user: c.user.sub}}

    refute OliWeb.SecureSocket.channel_allowed?(
             socket,
             "directed_discussion:#{c.section.slug}:#{c.revision.resource_id}"
           )
  end

  test "malformed index and oversized state projection produce typed denials", c do
    assert {:error, :not_found} =
             Boundary.check(c.normal, OliWeb.PageDeliveryController, :navigate_by_index, %{
               "section_slug" => c.section.slug,
               "page_number" => %{}
             })

    assert {:error, :invalid_batch} =
             Boundary.check(c.secure, OliWeb.Api.ResourceAttemptStateController, :read, %{
               "resource_attempt_guid" => c.attempt.attempt_guid,
               "keys" => List.duplicate("key", 101)
             })
  end

  test "nested page assistant rechecks current policy and credential", c do
    socket = %Phoenix.LiveView.Socket{
      view: OliWeb.Dialogue.WindowLive,
      assigns: %{user_session: c.normal}
    }

    params = %{"section_slug" => c.section.slug, "resource_id" => c.revision.resource_id}

    assert {:error, :secure_launch_required} =
             OliWeb.LiveSessionPlugs.SecureAssessment.authorize(socket, params)

    Accounts.delete_user_session_token(c.normal_token)

    assert {:error, :unauthenticated} =
             OliWeb.LiveSessionPlugs.SecureAssessment.authorize(socket, params)
  end

  test "component mutation cannot use a foreign GUID or a deleted credential", c do
    component = OliWeb.Delivery.Student.Lesson.Components.OneAtATimeQuestion
    params = %{"section_slug" => c.section.slug, "revision_slug" => c.revision.slug}

    socket = %Phoenix.LiveView.Socket{
      view: OliWeb.Delivery.Student.LessonLive,
      assigns: %{
        __changed__: %{},
        user_session: c.secure,
        secure_route_params: params,
        section_slug: c.section.slug,
        questions: [%{number: 1, state: %{"attemptGuid" => c.activity.attempt_guid}}]
      }
    }

    assert {:noreply, %{redirected: {:redirect, %{to: "/secure-assessment/restricted"}}}} =
             component.handle_event(
               "submit_selected_question",
               %{"attempt_guid" => "foreign", "question_id" => "question_1"},
               socket
             )

    Accounts.delete_user_session_token(c.secure_token)

    assert {:noreply, %{redirected: {:redirect, %{to: "/secure-assessment/restricted"}}}} =
             component.handle_event("select_question", %{"question_number" => 1}, socket)
  end

  @tag capture_log: true
  test "attempt batch is one query and unrelated ordinary LiveViews issue no policy queries", c do
    handler = "secure-query-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler,
      [:oli, :repo, :query],
      fn _, _, _, owner ->
        case self() == owner do
          true -> send(owner, :secure_query)
          false -> :ok
        end
      end,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert {:ok, [_]} =
             Policy.resolve_attempts(:activity, List.duplicate(c.activity.attempt_guid, 100))

    assert_receive :secure_query
    refute_receive :secure_query, 0

    socket = %Phoenix.LiveView.Socket{
      view: OliWeb.Delivery.Student.IndexLive,
      assigns: %{user_session: c.normal}
    }

    assert :ok = OliWeb.LiveSessionPlugs.SecureAssessment.authorize(socket, %{})
    refute_receive :secure_query, 0
  end

  @tag capture_log: true
  test "denial telemetry contains only bounded reason and transport", c do
    handler = "secure-denial-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler,
      [:oli, :secure_assessment, :denied],
      fn _, measurements, metadata, owner ->
        case self() == owner do
          true -> send(owner, {:denial, measurements, metadata})
          false -> :ok
        end
      end,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    Boundary.deny(c.conn, :secure_launch_required)

    assert_receive {:denial, %{count: 1},
                    %{reason: :secure_launch_required, transport: :http} = metadata}

    assert map_size(metadata) == 2
  end
end
