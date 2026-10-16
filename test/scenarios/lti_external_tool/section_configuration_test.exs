defmodule Oli.Scenarios.LtiExternalTool.SectionConfigurationTest do
  use OliWeb.ConnCase

  import Oli.Scenarios.LtiExternalTool.DeepLinkingHelpers

  import Mox

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.SectionDeepLinkLaunch
  alias Oli.Repo
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks

  @settings "https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings"
  @items "https://purl.imsglobal.org/spec/lti-dl/claim/content_items"

  setup :verify_on_exit!

  setup context do
    file =
      case context[:lifecycle] do
        true -> "section_configuration.scenario.yaml"
        _ -> "section_configuration_setup.scenario.yaml"
      end

    state = execute_scenario(Path.join(__DIR__, file))
    stub_tool_keyset(state)

    %{
      state: state,
      section: state.sections["draft_section"],
      resource_id: Hooks.activity(state).resource_id
    }
  end

  test "learners cannot request configuration parameters", %{
    state: state,
    section: section,
    resource_id: id
  } do
    response =
      build_conn()
      |> log_in_user(state.users["learner"])
      |> same_origin()
      |> post(details_path(section, id))

    assert json_response(response, 403)["error"]
  end

  test "configuration requires an enabled deployment and capability", %{
    state: state,
    section: section,
    resource_id: id
  } do
    for attrs <- [
          %{deep_linking_enabled: false},
          %{deep_linking_enabled: true, status: :disabled}
        ] do
      assert {:ok, _} =
               PlatformExternalTools.update_lti_external_tool_activity_deployment(
                 state.params.deployment,
                 attrs
               )

      response =
        build_conn()
        |> log_in_user(state.users["instructor"])
        |> same_origin()
        |> post(details_path(section, id))

      assert json_response(response, 403)["error"]
    end
  end

  test "malformed resource identifiers are refused without a query cast failure", %{
    state: state,
    section: section
  } do
    valid_id = Hooks.activity(state).resource_id
    {_details, settings} = configuration_launch(state, section, valid_id)

    for id <- ["invalid", "99999999999999999999", "-1", "0#{valid_id}", "+#{valid_id}"] do
      response =
        build_conn()
        |> log_in_user(state.users["instructor"])
        |> same_origin()
        |> post(details_path(section, id))

      assert json_response(response, 403)["error"]
    end

    jwt = signed_tool_response(state, settings["data"], selected_item(state))

    assert build_conn()
           |> post(callback_path(section, valid_id), %{JWT: jwt})
           |> html_response(200)
  end

  test "cross-origin or missing-origin preparation cannot supersede an active request", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)

    for origin <- [nil, "https://attacker.example"] do
      conn = build_conn() |> log_in_user(state.users["instructor"])

      conn =
        case origin do
          nil -> conn
          origin -> put_req_header(conn, "origin", origin)
        end

      assert conn |> post(details_path(section, id)) |> json_response(403)
    end

    jwt = signed_tool_response(state, settings["data"], selected_item(state))
    assert build_conn() |> post(callback_path(section, id), %{JWT: jwt}) |> html_response(200)
  end

  test "cancellation rejects late signed returns and cannot cancel a newer request", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {details, old_settings} = configuration_launch(state, section, id)
    before = selection(section, id)
    conn = build_conn() |> log_in_user(state.users["instructor"])

    cancel = fn token ->
      conn
      |> same_origin()
      |> post(~p"/api/v1/lti/sections/#{section.slug}/cancel_deep_linking/#{id}", %{
        request_token: token
      })
      |> json_response(200)
    end

    assert cancel.(details["request_token"])["status"] == "cancelled"

    assert_error(
      state,
      section,
      id,
      signed_tool_response(state, old_settings["data"], selected_item(state)),
      before
    )

    {_new_details, settings} = configuration_launch(state, section, id)
    assert cancel.(details["request_token"])["status"] == "cancelled"
    jwt = signed_tool_response(state, settings["data"], selected_item(state))
    assert build_conn() |> post(callback_path(section, id), %{JWT: jwt}) |> html_response(200)
  end

  test "a newer request supersedes older windows and cancelling a committed return reports completion",
       %{state: state, section: section, resource_id: id} do
    {_old_details, old_settings} = configuration_launch(state, section, id)
    {details, settings} = configuration_launch(state, section, id)

    jwt =
      signed_tool_response(state, settings["data"], selected_item(state), %{
        "aud" => ["another-audience", Oli.Utils.get_base_url()]
      })

    assert build_conn() |> post(callback_path(section, id), %{JWT: jwt}) |> html_response(200)
    saved = selection(section, id)

    assert_error(
      state,
      section,
      id,
      signed_tool_response(
        state,
        old_settings["data"],
        Map.put(selected_item(state), "url", "https://tool.example/late")
      ),
      saved
    )

    response =
      build_conn()
      |> log_in_user(state.users["instructor"])
      |> same_origin()
      |> post(~p"/api/v1/lti/sections/#{section.slug}/cancel_deep_linking/#{id}", %{
        request_token: details["request_token"]
      })

    assert json_response(response, 200)["status"] == "completed"
    assert selection(section, id) == saved
  end

  test "cancellation is bound to its initiating account and route", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {details, settings} = configuration_launch(state, section, id)

    for {actor, target_id, token} <- [
          {state.users["learner"], id, details["request_token"]},
          {state.users["instructor"], Hooks.activity(state, "unconfigured").resource_id,
           details["request_token"]},
          {state.users["instructor"], id, "invalid"}
        ] do
      response =
        build_conn()
        |> log_in_user(actor)
        |> same_origin()
        |> post(~p"/api/v1/lti/sections/#{section.slug}/cancel_deep_linking/#{target_id}", %{
          request_token: token
        })

      assert json_response(response, 403)["error"]
    end

    jwt = signed_tool_response(state, settings["data"], selected_item(state))
    assert build_conn() |> post(callback_path(section, id), %{JWT: jwt}) |> html_response(200)
  end

  test "invalid callback claims, correlation, route and content preserve selection", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)
    before = selection(section, id)

    {:ok, request} =
      Phoenix.Token.verify(OliWeb.Endpoint, "lti-section-request", settings["data"],
        max_age: 1800
      )

    expired_correlation =
      Phoenix.Token.sign(OliWeb.Endpoint, "lti-section-request", request,
        signed_at: System.system_time(:second) - 3600
      )

    invalid_responses =
      for overrides <- [
            %{"aud" => []},
            %{"aud" => [Oli.Utils.get_base_url(), 42]},
            %{@items => %{}},
            %{@items => :omit},
            %{"https://purl.imsglobal.org/spec/lti/claim/deployment_id" => Ecto.UUID.generate()},
            %{"https://purl.imsglobal.org/spec/lti/claim/version" => "1.2.0"},
            %{"exp" => System.system_time(:second) - 30}
          ] do
        signed_tool_response(state, settings["data"], selected_item(state), overrides)
      end

    invalid_responses =
      [
        signed_tool_response(state, nil, selected_item(state)),
        signed_tool_response(state, settings["data"] <> "tampered", selected_item(state)),
        signed_tool_response(state, expired_correlation, selected_item(state)),
        signed_tool_response(
          state,
          settings["data"],
          Map.put(selected_item(state), "url", "javascript:alert(1)")
        )
      ] ++ invalid_responses

    Enum.each(invalid_responses, fn jwt ->
      assert_error(
        state,
        section,
        id,
        jwt,
        before
      )
    end)

    state = Hooks.create_section(state, "other_section", state.params.draft_publication)
    other_section = state.sections["other_section"]
    moved_return = signed_tool_response(state, settings["data"], selected_item(state))
    assert_error(state, other_section, id, moved_return, selection(other_section, id))
    other_id = Hooks.activity(state, "unconfigured").resource_id
    assert_error(state, section, other_id, moved_return, nil)
    assert selection(section, id) == before

    assert SectionDeepLinkLaunch.resolve(state.users["learner"], section.slug, id) ==
             {:error, :configuration_unavailable}
  end

  @tag lifecycle: true
  test "instructor return changes only its section and is used by the next learner launch", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {details, settings} = configuration_launch(state, section, id)
    assert is_binary(details["request_id"])
    assert is_binary(settings["data"])

    assert settings["deep_link_return_url"] ==
             Oli.Utils.get_base_url() <> "/lti/deep_link/#{section.slug}/#{id}"

    selected = selected_item(state)
    jwt = signed_tool_response(state, settings["data"], selected)
    html = build_conn() |> post(callback_path(section, id), %{"JWT" => jwt}) |> html_response(200)
    assert html =~ "Resource Selected Successfully"
    refute html =~ "</script><script>window.injected"
    saved = selection(section, id)
    assert saved.url == selected["url"]
    assert saved.custom == selected["custom"]
    assert selection(state.sections["historical_section"], id).url == state.params.draft["url"]
    assert selection(state.sections["review_section"], id).url == state.params.review["url"]
    assert Hooks.activity(state).content["deepLink"] == state.params.review
    claims = learner_launch(state, section, id)
    assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] == selected["url"]
    assert claims["https://purl.imsglobal.org/spec/lti/claim/custom"] == selected["custom"]
    assert claims["sub"] == state.users["learner"].sub
  end

  @tag lifecycle: true
  test "section configuration sends its current string custom values without changing selection",
       %{
         state: state,
         section: section,
         resource_id: id
       } do
    custom = %{
      "mode" => "section-override",
      "task_json" =>
        Jason.encode!(%{task: "section-task", text: String.duplicate("task text ", 80)}),
      "empty" => "",
      "nested" => %{"task" => "legacy-object"},
      "number" => 42,
      "flag" => true,
      "null" => nil
    }

    assert {:ok, saved} =
             PlatformExternalTools.upsert_section_resource_deep_link(%{
               "section_id" => section.id,
               "resource_id" => id,
               "type" => "ltiResourceLink",
               "url" => "https://tool.example/section-override",
               "custom" => custom
             })

    saved = Repo.reload!(saved)
    conn = build_conn() |> log_in_user(state.users["instructor"])
    details = conn |> same_origin() |> post(details_path(section, id)) |> json_response(200)
    claims = authorize(conn, details["launch_params"])

    assert claims["https://purl.imsglobal.org/spec/lti/claim/custom"] ==
             Map.take(custom, ["mode", "task_json", "empty"])

    assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] ==
             state.params.platform.target_link_uri

    refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/resource_link")
    assert is_binary(claims[@settings]["data"])
    assert selection(section, id) == saved
    assert Hooks.activity(state).content["deepLink"] == state.params.review
    assert selection(state.sections["review_section"], id).custom == state.params.review["custom"]
  end

  @tag lifecycle: true
  test "configuration omits custom when the section selection is missing or contains no string values",
       %{
         state: state,
         section: section,
         resource_id: id
       } do
    unconfigured_id = Hooks.activity(state, "unconfigured").resource_id

    assert {:ok, saved} =
             PlatformExternalTools.upsert_section_resource_deep_link(%{
               "section_id" => section.id,
               "resource_id" => id,
               "type" => "ltiResourceLink",
               "url" => "https://tool.example/legacy",
               "custom" => %{"nested" => %{"task" => "legacy"}}
             })

    saved = Repo.reload!(saved)

    for resource_id <- [unconfigured_id, id] do
      conn = build_conn() |> log_in_user(state.users["instructor"])

      details =
        conn |> same_origin() |> post(details_path(section, resource_id)) |> json_response(200)

      claims = authorize(conn, details["launch_params"])
      refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/custom")

      assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] ==
               state.params.platform.target_link_uri
    end

    assert selection(section, unconfigured_id) == nil
    assert selection(section, id) == saved

    assert {:ok, _} = PlatformExternalTools.delete_section_resource_deep_link(saved)
    assert Hooks.activity(state).content["deepLink"] == state.params.review
    conn = build_conn() |> log_in_user(state.users["instructor"])
    details = conn |> same_origin() |> post(details_path(section, id)) |> json_response(200)
    claims = authorize(conn, details["launch_params"])
    refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/custom")

    assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] ==
             state.params.platform.target_link_uri

    assert selection(section, id) == nil
    assert selection(state.sections["review_section"], id).custom == state.params.review["custom"]
  end

  @tag lifecycle: true
  test "author deep linking sends current draft custom for either role and omits it without selection",
       %{state: state, section: section, resource_id: id} do
    conn = build_conn() |> log_in_author(state.current_author)
    current = Hooks.activity(state)

    page = state.projects["deep_linking_project"].rev_by_title["Tool Lesson"]
    project = Hooks.project(state).slug

    assert {:acquired} =
             Oli.Authoring.Locks.acquire(
               project,
               Oli.Publishing.project_working_publication(project).id,
               page.resource_id,
               state.current_author.id
             )

    for role <- ["developer", "instructor"], virtual_id <- ["configured", "unconfigured"] do
      activity = Hooks.activity(state, virtual_id)

      details =
        conn
        |> put_req_header("origin", Oli.Utils.get_base_url())
        |> post(
          ~p"/api/v1/lti/projects/#{Hooks.project(state).slug}/deep_linking_launch_details/#{activity.resource_id}",
          %{"role" => role, "lock_id" => page.resource_id}
        )
        |> json_response(200)

      claims = authorize(conn, details["launch_params"])

      case virtual_id do
        "configured" ->
          assert claims["https://purl.imsglobal.org/spec/lti/claim/custom"] ==
                   Map.take(state.params.review["custom"], ["mode", "task_json"])

        "unconfigured" ->
          refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/custom")
      end

      assert claims["https://purl.imsglobal.org/spec/lti/claim/message_type"] ==
               "LtiDeepLinkingRequest"

      assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] ==
               state.params.platform.target_link_uri

      refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/resource_link")
    end

    assert Hooks.activity(state) == current
    assert selection(section, id).custom == state.params.draft["custom"]
  end

  test "removed instructor permission invalidates an outstanding return", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)

    assert {:ok, _} =
             Sections.unenroll(state.users["instructor"].id, section.id, [
               ContextRoles.get_role(:context_instructor)
             ])

    jwt = signed_tool_response(state, settings["data"], selected_item(state))
    assert_error(state, section, id, jwt, selection(section, id))
  end

  test "disabling the capability invalidates an outstanding return", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)

    assert {:ok, _} =
             PlatformExternalTools.update_lti_external_tool_activity_deployment(
               state.params.deployment,
               %{deep_linking_enabled: false}
             )

    jwt = signed_tool_response(state, settings["data"], selected_item(state))
    assert_error(state, section, id, jwt, selection(section, id))
  end

  test "one configuration request cannot replace a selection twice", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)
    selected = selected_item(state)
    jwt = signed_tool_response(state, settings["data"], selected)
    assert build_conn() |> post(callback_path(section, id), %{"JWT" => jwt}) |> html_response(200)
    before = selection(section, id)

    replay =
      signed_tool_response(
        state,
        settings["data"],
        Map.put(selected, "url", "https://tool.example/replayed")
      )

    assert_error(state, section, id, replay, before)
  end

  test "administrators can configure without a delivery user session", %{
    state: state,
    section: section,
    resource_id: id
  } do
    conn = build_conn() |> log_in_author(state.current_author)
    details = conn |> same_origin() |> post(details_path(section, id)) |> json_response(200)
    claims = authorize(conn, details["launch_params"])
    assert claims["sub"] == "author-#{state.current_author.id}"

    assert ContextRoles.get_role(:context_instructor).uri in claims[
             "https://purl.imsglobal.org/spec/lti/claim/roles"
           ]

    jwt = signed_tool_response(state, claims[@settings]["data"], selected_item(state))
    assert build_conn() |> post(callback_path(section, id), %{"JWT" => jwt}) |> html_response(200)
    assert selection(section, id).url == selected_item(state)["url"]
  end

  test "a failed write preserves the selection and permits retrying the same request", %{
    state: state,
    section: section,
    resource_id: id
  } do
    {_details, settings} = configuration_launch(state, section, id)
    selected = Map.put(selected_item(state), "url", "https://tool.example/write-failure")
    before = selection(section, id)

    # Inject a real database failure inside this test's sandbox transaction, not a domain mock.
    Repo.query!("""
    ALTER TABLE lti_section_resource_deep_links ADD CONSTRAINT mer6018_write_failure
    CHECK (url <> 'https://tool.example/write-failure')
    """)

    jwt = signed_tool_response(state, settings["data"], selected)
    assert_error(state, section, id, jwt, before)

    Repo.query!(
      "ALTER TABLE lti_section_resource_deep_links DROP CONSTRAINT mer6018_write_failure"
    )

    jwt = signed_tool_response(state, settings["data"], selected)
    assert build_conn() |> post(callback_path(section, id), %{"JWT" => jwt}) |> html_response(200)
    assert selection(section, id).url == selected["url"]
  end

  test "authorization rechecks a hint after instructor access is revoked", %{
    state: state,
    section: section,
    resource_id: id
  } do
    conn = build_conn() |> log_in_user(state.users["instructor"])
    details = conn |> same_origin() |> post(details_path(section, id)) |> json_response(200)

    assert {:ok, _} =
             Sections.unenroll(state.users["instructor"].id, section.id, [
               ContextRoles.get_role(:context_instructor)
             ])

    response =
      conn
      |> get(~p"/lti/authorize_redirect", %{
        "login_hint" => details["launch_params"]["login_hint"],
        "client_id" => state.params.platform.client_id
      })

    assert response.status == 403
    assert selection(section, id).url == state.params.draft["url"]
  end

  defp assert_error(_state, section, id, jwt, before) do
    html = build_conn() |> post(callback_path(section, id), %{"JWT" => jwt}) |> html_response(400)
    assert html =~ "Deep Linking Failed"
    refute html =~ "Resource Selected Successfully"
    assert selection(section, id) == before
  end

  defp selected_item(state) do
    state.params.draft
    |> Map.put("url", "https://tool.example/instructor-selected")
    |> Map.put("title", "</script><script>window.injected = true</script>")
    |> Map.update!("custom", &Map.put(&1, "mode", "instructor-review"))
  end

  defp selection(section, id),
    do:
      PlatformExternalTools.get_section_resource_deep_link_by(
        section_id: section.id,
        resource_id: id
      )

  defp same_origin(conn),
    do:
      put_req_header(
        conn,
        "origin",
        Oli.Utils.get_base_url() |> URI.parse() |> Map.put(:path, nil) |> URI.to_string()
      )

  defp details_path(section, id),
    do: ~p"/api/v1/lti/sections/#{section.slug}/deep_linking_launch_details/#{id}"

  defp callback_path(section, id), do: ~p"/lti/deep_link/#{section.slug}/#{id}"

  defp configuration_launch(state, section, id) do
    conn = build_conn() |> log_in_user(state.users["instructor"])
    details = conn |> same_origin() |> post(details_path(section, id)) |> json_response(200)
    claims = authorize(conn, details["launch_params"])
    {details, claims[@settings]}
  end

  defp learner_launch(state, section, id) do
    conn = build_conn() |> log_in_user(state.users["learner"])

    details =
      conn
      |> get(~p"/api/v1/lti/sections/#{section.slug}/launch_details/#{id}")
      |> json_response(200)

    authorize(conn, details["launch_params"])
  end
end
