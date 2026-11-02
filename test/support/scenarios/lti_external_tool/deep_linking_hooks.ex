defmodule Oli.Scenarios.LtiExternalTool.DeepLinkingHooks do
  @moduledoc """
  Runs Deep Linking lifecycle steps not expressed by the generic scenario directives.

  In particular, courses must use `Delivery.create_section/1`: the generic section
  directive builds resources directly and bypasses inheritance of tool selections
  (resource configurations chosen in external tools, including URL/custom metadata).
  No external tool process or HTTP request is needed for these persistence tests.
  """

  import ExUnit.Assertions

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Locks
  alias Oli.Delivery
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  @project "deep_linking_project"

  @doc "Registers an enabled integration through the normal registration context."
  def register_tool(%ExecutionState{} = state) do
    assert {:ok, {platform, registration, deployment}} =
             PlatformExternalTools.register_lti_external_tool_activity(%{
               "name" => "Deep Linking Test Tool",
               "description" => "Protocol and persistence tests without a tool service",
               "client_id" => "deep-linking-test-client",
               "login_url" => "https://tool.example/login",
               "target_link_uri" => "https://tool.example/launch",
               "redirect_uris" => "https://tool.example/launch",
               "keyset_url" => "https://tool.example/jwks"
             })

    assert registration.slug == "deep_linking_test_tool"

    assert {:ok, deployment} =
             PlatformExternalTools.update_lti_external_tool_activity_deployment(deployment, %{
               deep_linking_enabled: true
             })

    %{state | params: Map.merge(state.params, %{platform: platform, deployment: deployment})}
  end

  @doc """
  Captures the chosen publication and its stored Draft selection (the resource
  configuration chosen in the external tool) for later snapshot/isolation assertions.
  """
  def capture_draft_publication(state) do
    publication = latest_publication(state)
    selection = activity(state).content["deepLink"]

    %{
      state
      | params: Map.merge(state.params, %{draft_publication: publication, draft: selection})
    }
  end

  @doc """
  Creates the first section from the published Draft selection (the external tool's
  resource configuration) to establish the original inheritance baseline.
  """
  def create_draft_section(state),
    do: create_section(state, "draft_section", state.params.draft_publication)

  @doc """
  Creates a section while the draft has a Review selection (the external tool's
  resource configuration), allowing tests to verify unpublished changes stay isolated.
  """
  def create_unpublished_section(state),
    do: create_section(state, "unpublished_section", latest_publication(state))

  @doc """
  Creates a section from the newly published Review selection (the external tool's
  resource configuration) to compare new inheritance with the original section.
  """
  def create_review_section(state),
    do: create_section(state, "review_section", latest_publication(state))

  @doc "Creates a section from an explicitly chosen older publication after republishing."
  def create_historical_section(state),
    do: create_section(state, "historical_section", state.params.draft_publication)

  @doc "Creates a course whose resources do not belong to the Deep Linking publication."
  def create_unrelated_section(state) do
    publication =
      Publishing.get_latest_published_publication_by_slug(
        state.projects["unrelated_project"].project.slug
      )

    create_section(state, "unrelated_section", publication)
  end

  @doc """
  Edits presentation through the activity editor and verifies that the selection
  (the external tool's chosen resource configuration) survives ordinary content saves.
  """
  def edit_presentation(state) do
    revision = activity(state)
    selection = revision.content["deepLink"]
    content = Map.put(revision.content, "height", 650)
    assert {:ok, saved} = save_content(state, content)
    assert saved.content["deepLink"] == selection
    assert activity(state).content == saved.content
    state
  end

  @doc """
  Replaces the persisted selection (the external tool's chosen resource configuration)
  with Review through the real activity editor, retaining unrelated presentation fields.
  """
  def select_review(state) do
    revision = activity(state)

    selection =
      revision.content["deepLink"]
      |> Map.put("url", "https://tool.example/review")
      |> Map.put("title", "Review Task")
      |> Map.update!("custom", &Map.put(&1, "mode", "review"))

    assert {:ok, saved} = save_content(state, Map.put(revision.content, "deepLink", selection))
    assert saved.resource_id == revision.resource_id
    assert saved.content["height"] == 650
    assert saved.content["authoring"] == revision.content["authoring"]
    %{state | params: Map.put(state.params, :review, selection)}
  end

  @doc "Creates a course with the same public command used by the creation wizard."
  def create_section(state, name, publication) do
    assert {:ok, request} = request(state, name, publication)
    assert {:ok, id, _slug} = Delivery.create_section(request)
    Engine.put_section(state, name, Sections.get_section!(id))
  end

  @doc "Builds an authorized direct-delivery request for an explicit publication."
  def request(state, title, publication) do
    SectionCreationRequest.new(
      state.current_author,
      "publication:#{publication.id}",
      %{title: title},
      SectionSpecification.direct()
    )
  end

  @doc "Returns the latest published snapshot, independently of the mutable working publication."
  def latest_publication(state),
    do: Publishing.get_latest_published_publication_by_slug(project(state).slug)

  @doc "Resolves the current persisted activity, avoiding the scenario's cached initial revision."
  def activity(state, virtual_id \\ "configured") do
    original = Map.fetch!(state.activity_virtual_ids, {@project, virtual_id})
    AuthoringResolver.from_resource_id(project(state).slug, original.resource_id)
  end

  @doc """
  Saves activity content through ActivityEditor using the containing page's lock.
  If the selection (the external tool's chosen resource configuration) changes,
  also submits it through the signed authoring-result path, without a running tool.
  """
  def save_content(state, content, virtual_id \\ "configured") do
    page = state.projects[@project].rev_by_title["Tool Lesson"]
    publication = Publishing.project_working_publication(project(state).slug)

    assert {:acquired} =
             Locks.acquire(
               project(state).slug,
               publication.id,
               page.resource_id,
               state.current_author.id
             )

    current = activity(state, virtual_id)
    project = project(state).slug
    selection = content["deepLink"]

    with {:ok, revision} <-
           ActivityEditor.edit(
             project,
             page.resource_id,
             current.resource_id,
             state.current_author.email,
             %{"content" => content}
           ) do
      result =
        case selection == current.content["deepLink"] do
          true ->
            {:ok, revision}

          false ->
            with {:ok, started} <-
                   Oli.Lti.AuthoringLaunch.start_request(
                     state.current_author,
                     project,
                     current.resource_id,
                     page.resource_id
                   ) do
              token = Oli.Lti.AuthoringLaunch.result_token(started.request, selection)

              Oli.Lti.AuthoringLaunch.save_result(
                state.current_author,
                project,
                current.resource_id,
                token
              )
            end
        end

      Locks.release(project, publication.id, page.resource_id, state.current_author.id)
      result
    end
  end

  @doc "Returns the project's persisted identity from the scenario."
  def project(state), do: state.projects[@project].project
end
