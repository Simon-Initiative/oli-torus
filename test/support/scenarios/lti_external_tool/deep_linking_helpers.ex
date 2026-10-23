defmodule Oli.Scenarios.LtiExternalTool.DeepLinkingHelpers do
  @moduledoc "Shared scenario, persistence and protocol helpers for the Deep Linking tests."

  import Ecto.Query
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [get: 3, html_response: 2]

  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Scenarios
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks
  alias Oli.Scenarios.RuntimeOpts

  @endpoint OliWeb.Endpoint
  @key_path "test/support/fixtures/test_rsa_private.pem"
  @kid "deep-linking-test-key"
  @items "https://purl.imsglobal.org/spec/lti-dl/claim/content_items"

  @doc "Validates and runs a scenario through real Torus APIs, returning its verified state."
  @spec execute_scenario(Path.t()) :: %Oli.Scenarios.DirectiveTypes.ExecutionState{}
  def execute_scenario(path) do
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, RuntimeOpts.build())
    assert result.errors == [], inspect(result.errors)
    assert result.verifications != []
    assert Enum.reject(result.verifications, & &1.passed) == [], inspect(result.verifications)
    result.state
  end

  @doc "Applies additional YAML directives to an existing scenario state."
  def apply_directives(state, yaml) do
    Enum.reduce(Oli.Scenarios.DirectiveParser.parse_yaml!(yaml), state, fn directive, state ->
      assert {:ok, state} = Oli.Scenarios.Engine.execute_directive(directive, state)
      state
    end)
  end

  @doc "Builds a portable resource selection (the external tool's chosen configuration)."
  def selection(mode),
    do: %{
      "type" => "ltiResourceLink",
      "url" => "https://tool.example/#{mode}",
      "custom" => %{"mode" => mode}
    }

  @doc "Builds a selection with long strings and structured custom values for lossless-transfer checks."
  def rich_selection(mode) do
    selection(mode)
    |> Map.put("url", "https://tool.example/#{mode}/" <> String.duplicate("x", 400))
    |> Map.put("title", String.duplicate("título ", 80))
    |> Map.put("text", String.duplicate("description ", 100))
    |> Map.put("custom", %{
      "mode" => mode,
      "nested" => %{"ids" => [1, 2]},
      "task_json" => "{\"id\":\"task\"}"
    })
  end

  @doc "Saves a project's selection through the signed authoring path used by the scenario hooks."
  def save_selection(state, name, selected) do
    assert {:ok, _} =
             Hooks.save_content(
               state,
               Map.put(Hooks.activity(state, name).content, "deepLink", selected),
               name
             )
  end

  @doc "Stores a section-local selection through the normal persistence context."
  def put_selection(section, id, selected) do
    assert {:ok, _} =
             PlatformExternalTools.upsert_section_resource_deep_link(
               Map.merge(selected, %{"section_id" => section.id, "resource_id" => id})
             )
  end

  @doc "Publishes the scenario's current project draft."
  def publish(state) do
    assert {:ok, publication} =
             Publishing.publish_project(
               Hooks.project(state),
               "Tool selection update",
               state.current_author.id
             )

    publication
  end

  @doc "Reads a persisted section-local selection without consulting project defaults."
  def link(section, id),
    do:
      PlatformExternalTools.get_section_resource_deep_link_by(
        section_id: section.id,
        resource_id: id
      )

  @doc "Reads section-local selections in stable resource order for snapshot comparisons."
  def links(section),
    do:
      Repo.all(
        from l in LtiSectionResourceDeepLink,
          where: l.section_id == ^section.id,
          order_by: l.resource_id
      )

  @doc "Reads a section's publication pins in stable project order."
  def pins(section),
    do:
      Repo.all(
        from p in SectionsProjectsPublications,
          where: p.section_id == ^section.id,
          order_by: p.project_id,
          select: {p.project_id, p.publication_id}
      )

  @doc "Completes OIDC authorization and verifies the platform signature before returning launch claims."
  def authorize(conn, params) do
    html =
      conn
      |> get("/lti/authorize_redirect", %{
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

    assert [token] =
             html |> Floki.parse_document!() |> Floki.attribute("input[name=id_token]", "value")

    {:ok, key} = Lti_1p3.get_active_jwk()

    assert {true, %JOSE.JWT{fields: claims}, _} =
             JOSE.JWT.verify(JOSE.JWK.from_pem(key.pem), token)

    claims
  end

  @doc "Stubs only the tool's remote keyset, independently of how many responses are signed or verified."
  def stub_tool_keyset(state) do
    {_, public} =
      @key_path
      |> File.read!()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()

    Mox.stub(Oli.Test.MockHTTP, :get, fn url ->
      assert url == state.params.platform.keyset_url

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: Jason.encode!(%{"keys" => [Map.put(public, "kid", @kid)]})
       }}
    end)
  end

  @doc "Signs a tool response using the test key; overrides may omit claims with :omit."
  def signed_tool_response(state, correlation, selected, overrides \\ %{}) do
    now = System.system_time(:second)

    claims =
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
        @items => [selected]
      }
      |> Map.merge(overrides)
      |> Enum.reject(fn {_key, value} -> value == :omit end)
      |> Map.new()

    @key_path
    |> File.read!()
    |> JOSE.JWK.from_pem()
    |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => @kid}, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end
end
