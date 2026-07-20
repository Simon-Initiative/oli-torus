defmodule Oli.Scenarios.Features.MixedContentHooks do
  @moduledoc """
  Scenario hooks that rebuild mixed-workflow context and assert author preview
  plus published delivery content after Playwright authoring steps.
  """

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [get: 2, html_response: 2]

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Types.BuiltProject
  alias OliWeb.Router.Helpers, as: Routes

  @endpoint OliWeb.Endpoint

  @project_name "workflow_authoring_project"
  @section_name "workflow_delivery_section"
  @page_title "Mixed Workflow Page"
  @author_name "workflow_author"
  @student_name "workflow_student"

  @doc """
  Rebuilds the scenario execution state from workflow params after a Playwright step.
  """
  def bind_workflow_context(%ExecutionState{} = state) do
    author = fetch_author_from_params!(state)
    student = fetch_student_from_params!(state)
    project = fetch_project_from_params!(state)
    section = fetch_section_from_params!(state)
    revision = fetch_revision_from_params!(state, project.slug)

    built_project = %BuiltProject{
      project: project,
      rev_by_title: %{@page_title => revision}
    }

    %{
      state
      | current_author: author,
        projects: Map.put(state.projects, @project_name, built_project),
        sections: Map.put(state.sections, @section_name, section),
        users:
          state.users
          |> Map.put(@author_name, author)
          |> Map.put(@student_name, student),
        params: Map.put(state.params || %{}, "workflow_page_revision_slug", revision.slug)
    }
  end

  @doc """
  Captures the authored page revision slug into scenario params for later workflow steps.
  """
  def capture_workflow_page_revision_slug(%ExecutionState{} = state) do
    revision = fetch_page_revision!(state)
    %{state | params: Map.put(state.params || %{}, "workflow_page_revision_slug", revision.slug)}
  end

  @doc """
  Asserts that the author preview renders the expected code block content.
  """
  def assert_author_preview_codeblock(%ExecutionState{} = state) do
    html = author_preview_html(state)
    text = html_text(html)

    assert_contains(text, state.params["EXPECTED_CODEBLOCK_CAPTION"])
    assert_contains(text, state.params["EXPECTED_CODEBLOCK_CODE"])

    state
  end

  @doc """
  Asserts that the text entered for the CORE-A workflow appears in author preview.
  """
  def assert_author_preview_core_text_editing(%ExecutionState{} = state) do
    state
    |> author_preview_html()
    |> html_text()
    |> assert_contains(required_param!(state, "EXPECTED_TYPED_TEXT"))

    state
  end

  @doc """
  Asserts that the published delivery revision contains the expected code block content.
  """
  def assert_student_delivery_codeblock(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_contains?(content, state.params["EXPECTED_CODEBLOCK_CAPTION"])
    assert nested_contains?(content, state.params["EXPECTED_CODEBLOCK_CODE"])

    state
  end

  @doc """
  Asserts that the text entered for the CORE-A workflow persists to published delivery content.
  """
  def assert_student_delivery_core_text_editing(%ExecutionState{} = state) do
    assert nested_contains?(
             delivered_revision_content(state),
             required_param!(state, "EXPECTED_TYPED_TEXT")
           )

    state
  end

  @doc """
  Asserts that the author preview renders the expected callout content.
  """
  def assert_author_preview_callout(%ExecutionState{} = state) do
    html = author_preview_html(state)
    text = html_text(html)

    assert_contains(text, state.params["EXPECTED_CALLOUT_TEXT"])

    state
  end

  @doc """
  Asserts that the published delivery revision contains the expected callout content.
  """
  def assert_student_delivery_callout(%ExecutionState{} = state) do
    content = delivered_revision_content(state)

    assert nested_contains?(content, state.params["EXPECTED_CALLOUT_TEXT"])

    state
  end

  defp author_preview_html(%ExecutionState{} = state) do
    author = fetch_user!(state, @author_name)
    built_project = fetch_project!(state)
    revision = fetch_page_revision!(state)

    build_conn_as_author(author)
    |> get(Routes.resource_path(@endpoint, :preview, built_project.project.slug, revision.slug))
    |> html_response(200)
  end

  defp delivered_revision_content(%ExecutionState{} = state) do
    section = fetch_section!(state)
    revision = fetch_page_revision!(state)

    case DeliveryResolver.from_resource_id(section.slug, revision.resource_id) do
      nil ->
        raise "Delivery revision for resource #{revision.resource_id} not found in section #{section.slug}"

      delivered_revision ->
        delivered_revision.content
    end
  end

  defp fetch_project!(%ExecutionState{} = state) do
    case Map.get(state.projects, @project_name) do
      nil -> raise "Project #{@project_name} not found in scenario state"
      built_project -> built_project
    end
  end

  defp fetch_section!(%ExecutionState{} = state) do
    case Map.get(state.sections, @section_name) do
      nil -> raise "Section #{@section_name} not found in scenario state"
      section -> section
    end
  end

  defp fetch_user!(%ExecutionState{} = state, name) do
    case Map.get(state.users, name) do
      nil -> raise "User #{name} not found in scenario state"
      user -> user
    end
  end

  defp fetch_page_revision!(%ExecutionState{} = state) do
    built_project = fetch_project!(state)

    case Map.get(built_project.rev_by_title, @page_title) do
      nil -> raise "Page #{@page_title} not found in built project"
      revision -> revision
    end
  end

  defp fetch_author_from_params!(%ExecutionState{} = state) do
    email = required_param!(state, "AUTHOR_EMAIL")

    case Accounts.get_author_by_email(email) do
      %Author{} = author -> author
      _ -> raise "Author with email #{email} not found"
    end
  end

  defp fetch_student_from_params!(%ExecutionState{} = state) do
    email = required_param!(state, "STUDENT_EMAIL")

    case Repo.get_by(User, email: email) do
      %User{} = user -> user
      _ -> raise "User with email #{email} not found"
    end
  end

  defp fetch_project_from_params!(%ExecutionState{} = state) do
    slug = required_param!(state, "PROJECT_SLUG")

    case Course.get_project_by_slug(slug) do
      nil -> raise "Project with slug #{slug} not found"
      project -> project
    end
  end

  defp fetch_section_from_params!(%ExecutionState{} = state) do
    slug = required_param!(state, "SECTION_SLUG")

    case Sections.get_section_by(slug: slug) do
      nil -> raise "Section with slug #{slug} not found"
      section -> section
    end
  end

  defp fetch_revision_from_params!(%ExecutionState{} = state, project_slug) do
    revision_slug = required_param!(state, "PAGE_REVISION_SLUG")

    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil -> raise "Revision with slug #{revision_slug} not found for project #{project_slug}"
      revision -> revision
    end
  end

  defp assert_contains(html, expected) when is_binary(expected) and expected != "" do
    assert html =~ expected
  end

  defp assert_contains(_html, expected) do
    raise "Expected non-empty string assertion value, got: #{inspect(expected)}"
  end

  defp required_param!(%ExecutionState{} = state, key) do
    case Map.get(state.params || %{}, key) do
      value when is_binary(value) and value != "" ->
        value

      value ->
        raise "Expected scenario param #{key} to be a non-empty string, got: #{inspect(value)}"
    end
  end

  defp html_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.text(sep: " ")
  end

  defp build_conn_as_author(author) do
    token = Accounts.generate_author_session_token(author)

    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:author_token, token)
    |> Plug.Conn.put_session(:current_author_id, author.id)
  end

  defp nested_contains?(value, expected) when is_binary(expected) and expected != "" do
    case value do
      text when is_binary(text) ->
        String.contains?(text, expected)

      ^expected ->
        true

      list when is_list(list) ->
        Enum.any?(list, &nested_contains?(&1, expected))

      map when is_map(map) ->
        map
        |> Map.values()
        |> Enum.any?(&nested_contains?(&1, expected))

      _ ->
        false
    end
  end

  defp nested_contains?(_value, _expected), do: false
end
