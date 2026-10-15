defmodule Oli.Scenarios.LtiExternalTool.DeepLinkingTest do
  use OliWeb.ConnCase

  import Ecto.Query
  import Mox

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Test.MockHTTP

  @custom_claim "https://purl.imsglobal.org/spec/lti/claim/custom"
  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"
  @resource_claim "https://purl.imsglobal.org/spec/lti/claim/resource_link"
  @target_claim "https://purl.imsglobal.org/spec/lti/claim/target_link_uri"
  @roles_claim "https://purl.imsglobal.org/spec/lti/claim/roles"
  @settings_claim "https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings"

  setup :verify_on_exit!

  test "published selections survive draft edits and remain independent across old and new sections" do
    state = execute_scenario("deep_linking_lifecycle.scenario.yaml")
    resource_id = Hooks.activity(state).resource_id
    draft = state.params.draft
    review = state.params.review

    for name <- ["draft_section", "unpublished_section", "historical_section"] do
      section = state.sections[name]
      assert_selection(section, resource_id, draft)
      assert_only_configured_selection(state, section)
      assert_publication(section, state.params.draft_publication)
    end

    review_section = state.sections["review_section"]
    assert_selection(review_section, resource_id, review)
    assert_only_configured_selection(state, review_section)
    assert_publication(review_section, Hooks.latest_publication(state))
    assert Hooks.activity(state).content["deepLink"] == review

    [published] =
      Publishing.get_published_activity_revisions(state.params.draft_publication.id, [resource_id])

    assert published.content["deepLink"] == draft
    assert published.content["height"] == 500
    assert Hooks.activity(state).content["height"] == 650

    learner = state.users["learner"]
    draft_section = state.sections["draft_section"]
    assert_launch(learner, draft_section, resource_id, draft)
    assert_launch(learner, review_section, resource_id, review)

    for virtual_id <- ["unconfigured", "cleared"] do
      unconfigured = Hooks.activity(state, virtual_id)
      claims = delivery_claims(learner, draft_section, unconfigured.resource_id)
      assert claims[@target_claim] == state.params.platform.target_link_uri
      refute Map.has_key?(claims, @custom_claim)
      assert claims[@context_claim]["id"] == draft_section.slug
      assert claims["sub"] == learner.sub
    end

    # Use the existing instructor-selection write boundary to prove independent ownership.
    override = Map.put(draft, "url", "https://tool.example/instructor-task")

    assert {:ok, _} =
             PlatformExternalTools.upsert_section_resource_deep_link(
               Map.merge(override, %{
                 "section_id" => draft_section.id,
                 "resource_id" => resource_id
               })
             )

    assert_launch(learner, draft_section, resource_id, override)
    assert_selection(review_section, resource_id, review)
    assert_selection(state.sections["historical_section"], resource_id, draft)
    assert Hooks.activity(state).content["deepLink"] == review
  end

  test "Regular authoring reuses selection and defaults without changing persisted content" do
    state = execute_scenario("deep_linking_setup.scenario.yaml")

    for virtual_id <- ["configured", "unconfigured", "cleared"] do
      revision = Hooks.activity(state, virtual_id)
      selection = revision.content["deepLink"]
      conn = build_conn() |> log_in_author(state.current_author)
      details = project_details(conn, state, revision.resource_id)
      claims = authorize(conn, details["launch_params"])

      expected_url = (selection && selection["url"]) || state.params.platform.target_link_uri
      assert details["launch_params"]["target_link_uri"] == expected_url
      assert claims[@target_claim] == expected_url
      assert claims[@context_claim]["id"] == Hooks.project(state).slug
      assert claims[@resource_claim]["id"] == to_string(revision.resource_id)
      assert claims["sub"] == "author-#{state.current_author.id}"
      assert ContextRoles.get_role(:context_content_developer).uri in claims[@roles_claim]

      case selection do
        nil -> refute Map.has_key?(claims, @custom_claim)
        selected -> assert claims[@custom_claim] == selected["custom"]
      end

      assert Hooks.activity(state, virtual_id).content == revision.content
    end
  end

  test "a signed authoring return is saved, published and used by a learner" do
    state = execute_scenario("deep_linking_setup.scenario.yaml")
    revision = Hooks.activity(state)
    conn = build_conn() |> log_in_author(state.current_author)

    details =
      project_details(conn, state, revision.resource_id, %{
        "role" => "developer",
        "launch_type" => "deep_link"
      })

    claims = authorize(conn, details["launch_params"])
    assert claims[@settings_claim]["accept_types"] == ["ltiResourceLink"]
    assert claims[@settings_claim]["accept_multiple"] == false
    refute Map.has_key?(claims, @resource_claim)

    selected =
      revision.content["deepLink"]
      |> Map.put("url", "https://tool.example/selected-task")
      |> Map.put("title", "Selected Task")

    jwt = signed_tool_response(state, claims[@settings_claim]["data"], selected)

    html =
      build_conn()
      |> post(~p"/lti/authoring_deep_link", %{"JWT" => jwt})
      |> html_response(200)

    [result_json] =
      html |> Floki.parse_document!() |> Floki.attribute("#authoring-result", "data-result")

    result = Jason.decode!(result_json)
    refute Map.has_key?(result, "error")
    assert result["request_id"] == details["request_id"]
    assert Hooks.activity(state).content == revision.content

    response =
      conn
      |> put_req_header("origin", Oli.Utils.get_base_url())
      |> post(
        ~p"/api/v1/lti/projects/#{Hooks.project(state).slug}/deep_link_save/#{revision.resource_id}",
        %{token: result["token"]}
      )
      |> json_response(200)

    saved = Hooks.activity(state)
    assert response["model"] == saved.content
    assert saved.content["deepLink"] == selected
    assert saved.resource_id == revision.resource_id
    assert Map.delete(saved.content, "deepLink") == Map.delete(revision.content, "deepLink")

    {:ok, publication} =
      Publishing.publish_project(Hooks.project(state), "Saved selection", state.current_author.id)

    state = Hooks.create_section(state, "selected_section", publication)
    section = state.sections["selected_section"]
    learner = state.users["learner"]
    {:ok, _} = Sections.enroll(learner.id, section.id, [ContextRoles.get_role(:context_learner)])
    assert_selection(section, revision.resource_id, selected)
    assert_launch(learner, section, revision.resource_id, selected)
  end

  test "author callback refuses invalid signed protocol/content returns without issuing a selection token" do
    state = execute_scenario("deep_linking_setup.scenario.yaml")
    revision = Hooks.activity(state)
    conn = build_conn() |> log_in_author(state.current_author)

    details =
      project_details(conn, state, revision.resource_id, %{
        "role" => "developer",
        "launch_type" => "deep_link"
      })

    claims = authorize(conn, details["launch_params"])
    data = claims[@settings_claim]["data"]
    selected = revision.content["deepLink"]
    items = "https://purl.imsglobal.org/spec/lti-dl/claim/content_items"

    invalid_returns = [
      %{items => :delete},
      %{items => []},
      %{items => [selected, selected]},
      %{items => [%{"type" => "unsupported"}]},
      %{items => [Map.put(selected, "url", "javascript:alert(1)")]},
      %{items => [Map.put(selected, "custom", ["invalid"])]},
      %{items => [Map.put(selected, "title", %{"html" => "invalid"})]},
      %{"aud" => "https://wrong-platform.example"},
      %{"exp" => 0},
      %{"https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest"},
      %{"https://purl.imsglobal.org/spec/lti/claim/version" => "1.2"},
      %{"https://purl.imsglobal.org/spec/lti/claim/deployment_id" => "other-deployment"}
    ]

    for override <- invalid_returns do
      jwt = signed_tool_response(state, data, selected, override)
      assert_authoring_error(jwt, state, revision)
    end

    jwt = signed_tool_response(state, data, selected)
    [header, payload, signature] = String.split(jwt, ".")

    replacement =
      case String.first(signature) do
        "A" -> "B"
        _ -> "A"
      end

    invalid_signature = replacement <> String.slice(signature, 1..-1//1)
    assert_authoring_error(Enum.join([header, payload, invalid_signature], "."), state, revision)
  end

  defp assert_authoring_error(jwt, state, revision) do
    html =
      build_conn() |> post(~p"/lti/authoring_deep_link", %{"JWT" => jwt}) |> html_response(200)

    [result] =
      html |> Floki.parse_document!() |> Floki.attribute("#authoring-result", "data-result")

    result = Jason.decode!(result)
    assert is_binary(result["error"])
    refute Map.has_key?(result, "token")
    assert Hooks.activity(state).id == revision.id
    assert Hooks.activity(state).content == revision.content
  end

  test "long URL and descriptive metadata survive publication and section initialization" do
    state = execute_scenario("deep_linking_setup.scenario.yaml")
    revision = Hooks.activity(state)

    selected =
      revision.content["deepLink"]
      |> Map.put("url", "https://tool.example/" <> String.duplicate("a", 300))
      |> Map.put("title", String.duplicate("Task ", 70))
      |> Map.put("text", String.duplicate("Description ", 40))

    assert {:ok, _} = Hooks.save_content(state, Map.put(revision.content, "deepLink", selected))

    {:ok, publication} =
      Publishing.publish_project(Hooks.project(state), "Long metadata", state.current_author.id)

    state = Hooks.create_section(state, "long_metadata_section", publication)
    assert_selection(state.sections["long_metadata_section"], revision.resource_id, selected)
  end

  test "invalid published selection rolls back the whole course creation" do
    state = execute_scenario("deep_linking_setup.scenario.yaml")
    revision = Hooks.activity(state, "unconfigured")
    invalid = Map.put(Hooks.activity(state).content["deepLink"], "type", "unsupported")

    # Deliberately corrupt legacy storage; ordinary editor requests cannot create this state.
    assert {:ok, _} =
             Oli.Resources.update_revision(revision, %{
               content: Map.put(revision.content, "deepLink", invalid)
             })

    {:ok, publication} =
      Publishing.publish_project(
        Hooks.project(state),
        "Invalid selection",
        state.current_author.id
      )

    {:ok, request} = Hooks.request(state, "Must not survive", publication)
    before = creation_counts()

    assert {:error, :invalid_lti_deep_link_selection} = Delivery.create_section(request)
    assert creation_counts() == before
  end

  test "publication initialization does not leak selections into an unrelated destination" do
    state = execute_scenario("deep_linking_membership.scenario.yaml")
    section = state.sections["unrelated_section"]

    assert {:ok, 0} =
             PlatformExternalTools.initialize_section_deep_links(
               section.id,
               state.params.draft_publication.id
             )

    assert Repo.aggregate(
             from(link in LtiSectionResourceDeepLink, where: link.section_id == ^section.id),
             :count
           ) == 0

    assert_publication(
      section,
      Publishing.get_latest_published_publication_by_slug(
        state.projects["unrelated_project"].project.slug
      )
    )
  end

  defp creation_counts do
    Map.new(
      [
        "sections",
        "section_resources",
        "sections_projects_publications",
        "lti_section_resource_deep_links",
        "enrollments"
      ],
      &{&1, Repo.aggregate(&1, :count)}
    )
  end

  defp project_details(conn, state, resource_id, choices \\ %{}) do
    case choices["launch_type"] do
      "deep_link" ->
        project = Hooks.project(state).slug
        page = state.projects["deep_linking_project"].rev_by_title["Tool Lesson"]

        assert {:acquired} =
                 Oli.Authoring.Locks.acquire(
                   project,
                   Publishing.project_working_publication(project).id,
                   page.resource_id,
                   state.current_author.id
                 )

        conn
        |> put_req_header("origin", Oli.Utils.get_base_url())
        |> post(
          ~p"/api/v1/lti/projects/#{project}/deep_linking_launch_details/#{resource_id}",
          Map.put(choices, "lock_id", page.resource_id)
        )
        |> json_response(200)

      _ ->
        conn
        |> get(
          ~p"/api/v1/lti/projects/#{Hooks.project(state).slug}/launch_details/#{resource_id}",
          choices
        )
        |> json_response(200)
    end
  end

  defp signed_tool_response(state, correlation, selected, overrides \\ %{}) do
    key = "test/support/fixtures/test_rsa_private.pem" |> File.read!() |> JOSE.JWK.from_pem()
    {_, public} = key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    public = Map.put(public, "kid", "deep-linking-test-key")

    expect(MockHTTP, :get, fn url ->
      assert url == state.params.platform.keyset_url
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"keys" => [public]})}}
    end)

    now = System.system_time(:second)

    fields =
      %{
        "iss" => state.params.platform.client_id,
        "aud" => Oli.Utils.get_base_url(),
        "iat" => now,
        "exp" => now + 300,
        "jti" => Ecto.UUID.generate(),
        "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiDeepLinkingResponse",
        "https://purl.imsglobal.org/spec/lti/claim/version" => "1.3.0",
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" =>
          state.params.deployment.deployment_id,
        "https://purl.imsglobal.org/spec/lti-dl/claim/data" => correlation,
        "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => [selected]
      }
      |> Map.merge(overrides)
      |> Enum.reject(fn {_key, value} -> value == :delete end)
      |> Map.new()

    JOSE.JWT.sign(key, %{"alg" => "RS256", "kid" => "deep-linking-test-key"}, fields)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  defp execute_scenario(filename) do
    path = Path.join(__DIR__, filename)
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == [], "Scenario errors: #{inspect(result.errors)}"
    assert result.verifications != []

    failed = Enum.reject(result.verifications, & &1.passed)
    assert failed == [], "Scenario failures: #{inspect(failed)}"
    result.state
  end

  defp assert_selection(section, resource_id, expected) do
    selection =
      PlatformExternalTools.get_section_resource_deep_link_by(
        section_id: section.id,
        resource_id: resource_id
      )

    assert selection != nil
    assert selection.type == :ltiResourceLink

    assert Map.take(Map.from_struct(selection), [:url, :custom, :title, :text]) == %{
             url: expected["url"],
             custom: expected["custom"],
             title: expected["title"],
             text: expected["text"]
           }
  end

  defp assert_only_configured_selection(state, section) do
    assert Repo.aggregate(
             from(link in LtiSectionResourceDeepLink, where: link.section_id == ^section.id),
             :count
           ) == 1

    for virtual_id <- ["unconfigured", "cleared"] do
      assert PlatformExternalTools.get_section_resource_deep_link_by(
               section_id: section.id,
               resource_id: Hooks.activity(state, virtual_id).resource_id
             ) == nil
    end
  end

  defp assert_publication(section, publication) do
    assert Repo.get_by!(SectionsProjectsPublications, section_id: section.id).publication_id ==
             publication.id
  end

  defp assert_launch(learner, section, resource_id, selection) do
    claims = delivery_claims(learner, section, resource_id)
    assert claims[@target_claim] == selection["url"]
    assert claims[@custom_claim] == selection["custom"]
    assert claims[@context_claim]["id"] == section.slug
    assert claims[@resource_claim]["id"] == to_string(resource_id)
    assert claims["sub"] == learner.sub
    assert claims["email"] == learner.email
  end

  defp delivery_claims(learner, section, resource_id) do
    conn = build_conn() |> log_in_user(learner)

    details =
      conn
      |> get(~p"/api/v1/lti/sections/#{section.slug}/launch_details/#{resource_id}")
      |> json_response(200)

    authorize(conn, details["launch_params"])
  end

  defp authorize(conn, launch_params) do
    html =
      conn
      |> get(~p"/lti/authorize_redirect", %{
        "client_id" => launch_params["client_id"],
        "login_hint" => launch_params["login_hint"],
        "lti_message_hint" => launch_params["lti_message_hint"],
        "nonce" => Ecto.UUID.generate(),
        "state" => Ecto.UUID.generate(),
        "prompt" => "none",
        "redirect_uri" => "https://tool.example/launch",
        "response_mode" => "form_post",
        "response_type" => "id_token",
        "scope" => "openid"
      })
      |> html_response(200)

    assert [token] =
             html |> Floki.parse_document!() |> Floki.attribute("input[name=id_token]", "value"),
           "Authorization did not return a token: #{Floki.text(Floki.parse_document!(html))}"

    {:ok, key} = Lti_1p3.get_active_jwk()
    public_key = key.pem |> JOSE.JWK.from_pem() |> JOSE.JWK.to_public()
    assert {true, %JOSE.JWT{fields: claims}, _} = JOSE.JWT.verify(public_key, token)
    claims
  end
end
