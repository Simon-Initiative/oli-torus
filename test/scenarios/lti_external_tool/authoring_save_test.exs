defmodule Oli.Scenarios.LtiExternalTool.AuthoringSaveTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Locks
  alias Oli.Lti.AuthoringLaunch
  alias Oli.Publishing
  alias Oli.Resources
  alias Oli.Scenarios
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks
  alias Oli.Scenarios.RuntimeOpts

  setup do
    path = Path.join(__DIR__, "deep_linking_setup.scenario.yaml")
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == [], inspect(result.errors)
    assert Enum.all?(result.verifications, & &1.passed)
    state = result.state
    project = Hooks.project(state)
    page = state.projects["deep_linking_project"].rev_by_title["Tool Lesson"]
    publication = Publishing.project_working_publication(project.slug)

    assert {:acquired} =
             Locks.acquire(
               project.slug,
               publication.id,
               page.resource_id,
               state.current_author.id
             )

    %{
      state: state,
      project: project,
      page: page,
      publication: publication,
      author: state.current_author,
      activity: Hooks.activity(state)
    }
  end

  test "ordinary same-lock LTI edits preserve selection and existing revision policy", ctx do
    assert {:ok, first} = edit(ctx, Map.put(ctx.activity.content, "height", 650))
    stale = first.content |> Map.put("height", 700) |> Map.put("deepLink", selection())
    assert {:ok, second} = edit(ctx, stale)
    assert second.id == first.id
    assert second.content["deepLink"] == ctx.activity.content["deepLink"]
    assert second.content["height"] == 700
  end

  test "bulk same-lock LTI edits preserve selection and existing revision policy", ctx do
    assert {:ok, first} = edit(ctx, ctx.activity.content)

    update = %{
      "resource_id" => ctx.activity.resource_id,
      "content" => Map.delete(first.content, "deepLink") |> Map.put("height", 720)
    }

    assert {:ok, [second]} =
             ActivityEditor.bulk_edit(ctx.project.slug, ctx.page.resource_id, ctx.author.email, [
               update
             ])

    assert second.id == first.id
    assert second.content["deepLink"] == ctx.activity.content["deepLink"]
    assert second.content["height"] == 720
  end

  test "guarded save changes only selection, advances the mapping and rejects replay", ctx do
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())

    assert {:ok, saved} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert saved.id != ctx.activity.id
    assert saved.resource_id == ctx.activity.resource_id
    assert saved.content["deepLink"] == selection()
    assert Map.delete(saved.content, "deepLink") == Map.delete(ctx.activity.content, "deepLink")
    assert saved.title == ctx.activity.title
    assert saved.objectives == ctx.activity.objectives
    assert saved.tags == ctx.activity.tags
    assert Hooks.activity(ctx.state).id == saved.id

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert Hooks.activity(ctx.state).id == saved.id
  end

  test "an ordinary edit under the same lock makes an older signed result stale", ctx do
    assert {:ok, warm} = edit(ctx, Map.put(ctx.activity.content, "height", 650))
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())
    assert {:ok, current} = edit(ctx, Map.put(ctx.activity.content, "height", 900))

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert current.id == warm.id
    assert Hooks.activity(ctx.state).id == current.id
    assert Hooks.activity(ctx.state).content["height"] == 900
    assert Hooks.activity(ctx.state).content["deepLink"] == ctx.activity.content["deepLink"]
  end

  test "lost editing access prevents launch and save", ctx do
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())

    assert {:ok} =
             Locks.release(
               ctx.project.slug,
               ctx.publication.id,
               ctx.page.resource_id,
               ctx.author.id
             )

    assert {:error, _} = start(ctx)

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  test "cross-associated and tampered result tokens cannot update an activity", ctx do
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())
    other_id = Hooks.activity(ctx.state, "unconfigured").resource_id

    assert {:error, _} =
             AuthoringLaunch.save_result(ctx.author, ctx.project.slug, other_id, token)

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token <> "tampered"
             )

    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  test "published revisions stay frozen when a later configuration is saved", ctx do
    assert {:ok, published} =
             Publishing.publish_project(ctx.project, "Frozen selection", ctx.author.id)

    assert {:acquired} =
             Locks.acquire(
               ctx.project.slug,
               Publishing.project_working_publication(ctx.project.slug).id,
               ctx.page.resource_id,
               ctx.author.id
             )

    frozen = Publishing.get_published_revision(published.id, ctx.activity.resource_id)
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())

    assert {:ok, saved} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert saved.id != frozen.id
    assert Resources.get_revision!(frozen.id).content == frozen.content
  end

  test "lost integration capability prevents result validation and saving",
       ctx do
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())

    assert {:ok, _} =
             Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity_deployment(
               started.deployment,
               %{deep_linking_enabled: false}
             )

    assert {:error, _} =
             AuthoringLaunch.validate_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  test "revoked accepted collaboration prevents every outstanding save", ctx do
    assert {:ok, author} =
             Accounts.update_author(ctx.author, %{
               system_role_id: Oli.Accounts.SystemRole.role_id().author
             })

    ctx = %{ctx | author: author}
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())
    membership = Course.get_author_project(ctx.project.slug, author.id)
    Repo.delete!(membership)
    assert {:error, _} = start(ctx)

    assert {:error, _} =
             AuthoringLaunch.save_result(
               author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )
  end

  test "expired result tokens and mismatched deployment/version/issuer returns are rejected",
       ctx do
    assert {:ok, started} = start(ctx)

    token =
      Phoenix.Token.sign(
        OliWeb.Endpoint,
        "lti-authoring-result",
        %{"request" => started.request, "selection" => selection()},
        signed_at: System.system_time(:second) - 700
      )

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    claims = %{
      "iss" => started.deployment.platform_instance.client_id,
      "exp" => System.system_time(:second) + 300,
      "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0",
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" =>
        started.deployment.deployment_id,
      "https://purl.imsglobal.org/spec/lti-dl/claim/data" => started.request_token
    }

    assert {:ok, _} = AuthoringLaunch.validate_return(claims)

    for {key, value} <- [
          {"iss", "other-tool"},
          {"exp", 0},
          {"https://purl.imsglobal.org/spec/lti/claim/version", "1.2"},
          {"https://purl.imsglobal.org/spec/lti/claim/deployment_id", "other-deployment"}
        ] do
      assert {:error, _} = AuthoringLaunch.validate_return(Map.put(claims, key, value))
    end

    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  test "a database constraint failure rolls back revision and mapping and allows retry",
       ctx do
    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())
    before_count = Repo.aggregate(Oli.Resources.Revision, :count)

    Repo.query!(
      "ALTER TABLE revisions ADD CONSTRAINT mer6018_authoring_failure CHECK (content->'deepLink'->>'url' IS DISTINCT FROM 'https://tool.example/selected')"
    )

    assert {:error, :save_failed} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert Hooks.activity(ctx.state).id == ctx.activity.id
    assert Repo.aggregate(Oli.Resources.Revision, :count) == before_count

    assert {:ok, _, _} =
             AuthoringLaunch.validate_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    Repo.query!("ALTER TABLE revisions DROP CONSTRAINT mer6018_authoring_failure")

    assert {:ok, saved} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert saved.content["deepLink"] == selection()

    assert Hooks.activity(ctx.state).id == saved.id
  end

  test "ordinary storage API preserves selection and rejects legacy Deep Link GET",
       ctx do
    conn = build_conn() |> log_in_author(ctx.author)

    conn
    |> get(
      ~p"/api/v1/lti/projects/#{ctx.project.slug}/launch_details/#{ctx.activity.resource_id}",
      %{launch_type: "deep_link"}
    )
    |> json_response(403)

    response =
      conn
      |> put(
        "/api/v1/storage/project/#{ctx.project.slug}/resource/#{ctx.activity.resource_id}?lock=#{ctx.page.resource_id}",
        %{content: Map.put(ctx.activity.content, "deepLink", selection())}
      )
      |> json_response(200)

    assert response["result"] == "success"
    assert Hooks.activity(ctx.state).content["deepLink"] == ctx.activity.content["deepLink"]
  end

  test "configuration POST requires trusted origin and an owned page lock", ctx do
    conn = build_conn() |> log_in_author(ctx.author)

    path =
      ~p"/api/v1/lti/projects/#{ctx.project.slug}/deep_linking_launch_details/#{ctx.activity.resource_id}"

    conn |> post(path, %{lock_id: ctx.page.resource_id}) |> json_response(403)

    conn
    |> put_req_header("origin", "https://attacker.example")
    |> post(path, %{lock_id: ctx.page.resource_id})
    |> json_response(403)

    conn
    |> put_req_header("origin", Oli.Utils.get_base_url())
    |> post(path, %{})
    |> json_response(400)

    conn
    |> put_req_header("origin", Oli.Utils.get_base_url())
    |> post(path, %{lock_id: ctx.page.resource_id, role: "student"})
    |> json_response(403)

    conn
    |> put_req_header("origin", Oli.Utils.get_base_url())
    |> post(path, %{lock_id: ctx.page.resource_id, role: "instructor"})
    |> json_response(200)
  end

  test "ordinary single and bulk null content cannot clear an LTI selection", ctx do
    assert {:error, {:invalid_update_field}} = edit(ctx, nil)

    assert {:error, {:invalid_update_field}} =
             ActivityEditor.bulk_edit(ctx.project.slug, ctx.page.resource_id, ctx.author.email, [
               %{"resource_id" => ctx.activity.resource_id, "content" => nil}
             ])

    assert Hooks.activity(ctx.state).id == ctx.activity.id
    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  test "the four role/type choices produce their intended claims and preserve captured request data",
       ctx do
    conn = build_conn() |> log_in_author(ctx.author)

    for role <- ["developer", "instructor"], type <- ["regular", "deep_link"] do
      details =
        case type do
          "regular" ->
            conn
            |> get(
              ~p"/api/v1/lti/projects/#{ctx.project.slug}/launch_details/#{ctx.activity.resource_id}",
              %{role: role}
            )
            |> json_response(200)

          "deep_link" ->
            conn
            |> put_req_header("origin", Oli.Utils.get_base_url())
            |> post(
              ~p"/api/v1/lti/projects/#{ctx.project.slug}/deep_linking_launch_details/#{ctx.activity.resource_id}",
              %{role: role, lock_id: ctx.page.resource_id}
            )
            |> json_response(200)
        end

      params = details["launch_params"]

      html =
        conn
        |> get(~p"/lti/authorize_redirect", %{
          "client_id" => params["client_id"],
          "login_hint" => params["login_hint"],
          "lti_message_hint" => params["lti_message_hint"],
          "nonce" => Ecto.UUID.generate(),
          "state" => Ecto.UUID.generate(),
          "prompt" => "none",
          "redirect_uri" => "https://tool.example/launch",
          "response_mode" => "form_post",
          "response_type" => "id_token",
          "scope" => "openid"
        })
        |> html_response(200)

      [token] =
        html |> Floki.parse_document!() |> Floki.attribute("input[name=id_token]", "value")

      {:ok, jwk} = Lti_1p3.get_active_jwk()

      assert {true, %JOSE.JWT{fields: claims}, _} =
               JOSE.JWT.verify(JOSE.JWK.from_pem(jwk.pem), token)

      expected_role =
        case role do
          "developer" -> :context_content_developer
          "instructor" -> :context_instructor
        end

      assert Lti_1p3.Roles.ContextRoles.get_role(expected_role).uri in claims[
               "https://purl.imsglobal.org/spec/lti/claim/roles"
             ]

      case type do
        "deep_link" ->
          assert claims["https://purl.imsglobal.org/spec/lti/claim/message_type"] ==
                   "LtiDeepLinkingRequest"

          assert claims["https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings"][
                   "data"
                 ] == details["request_token"]

          refute Map.has_key?(claims, "https://purl.imsglobal.org/spec/lti/claim/resource_link")

        "regular" ->
          assert claims["https://purl.imsglobal.org/spec/lti/claim/message_type"] ==
                   "LtiResourceLinkRequest"

          assert claims["https://purl.imsglobal.org/spec/lti/claim/target_link_uri"] ==
                   ctx.activity.content["deepLink"]["url"]
      end
    end
  end

  test "a lock must belong to the activity's editor and removed references refuse save", ctx do
    # Even an owned activity lock cannot substitute for the containing page's lock on an embedded activity.
    assert {:acquired} =
             Locks.acquire(
               ctx.project.slug,
               ctx.publication.id,
               ctx.activity.resource_id,
               ctx.author.id
             )

    assert {:error, _} =
             AuthoringLaunch.start_request(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               ctx.activity.resource_id
             )

    assert {:ok, started} = start(ctx)
    token = AuthoringLaunch.result_token(started.request, selection())

    assert {:ok, _} =
             Resources.update_revision(ctx.page, %{
               content: Map.put(ctx.page.content, "model", [])
             })

    assert {:error, _} =
             AuthoringLaunch.save_result(
               ctx.author,
               ctx.project.slug,
               ctx.activity.resource_id,
               token
             )

    assert Hooks.activity(ctx.state).content == ctx.activity.content
  end

  defp start(ctx),
    do:
      AuthoringLaunch.start_request(
        ctx.author,
        ctx.project.slug,
        ctx.activity.resource_id,
        ctx.page.resource_id
      )

  defp edit(ctx, content),
    do:
      ActivityEditor.edit(
        ctx.project.slug,
        ctx.page.resource_id,
        ctx.activity.resource_id,
        ctx.author.email,
        %{"content" => content}
      )

  defp selection,
    do: %{
      "type" => "ltiResourceLink",
      "url" => "https://tool.example/selected",
      "title" => "Selected Task",
      "custom" => %{"mode" => "review"}
    }
end
