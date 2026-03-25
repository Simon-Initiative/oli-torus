defmodule Oli.Scenarios.Directives.VisitPageHandler do
  @moduledoc """
  Handles visit_page directives for simulating students visiting pages.

  This handler delegates to the same delivery page-visit orchestration used by
  production page rendering, storing the resulting attempt state in the execution state.
  """

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle.Graded
  alias Oli.Delivery.Attempts.PageLifecycle.VisitContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, VisitPageDirective}

  def handle(%VisitPageDirective{} = directive, %ExecutionState{} = state) do
    handle_visit(directive.student, directive.section, directive.page, state)
  end

  def handle_visit(student_name, section_name, page_title, %ExecutionState{} = state) do
    with {:ok, user} <- get_user(state, student_name),
         {:ok, section} <- get_section(state, section_name),
         {:ok, _enrollment} <- ensure_enrollment(user, section),
         {:ok, page_revision} <- get_page_revision(state, section_name, page_title),
         {:ok, attempt_result} <- visit_page(user, section, page_revision) do
      key = {student_name, section_name, page_title}
      updated_attempts = Map.put(state.page_attempts, key, attempt_result)

      {:ok, %{state | page_attempts: updated_attempts}}
    else
      {:error, reason} ->
        {:error, "Failed to visit page: #{reason}"}
    end
  end

  defp get_user(state, user_name) do
    case Map.get(state.users, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  defp get_section(state, section_name) do
    case Map.get(state.sections, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  defp ensure_enrollment(user, section) do
    case Sections.get_enrollment(section.slug, user.id) do
      nil ->
        learner_role = ContextRoles.get_role(:context_learner)

        case Sections.enroll([user.id], section.id, [learner_role]) do
          {:ok, _enrollments} -> {:ok, :enrolled}
          error -> {:error, "Failed to enroll: #{inspect(error)}"}
        end

      _enrollment ->
        {:ok, :already_enrolled}
    end
  end

  defp get_page_revision(state, section_name, page_title) do
    with {:ok, section} <- get_section(state, section_name),
         {:ok, project} <- get_project_for_section(state, section),
         {:ok, page_rev} <- get_page_from_project(project, page_title) do
      case DeliveryResolver.from_revision_slug(section.slug, page_rev.slug) do
        nil -> {:error, "Page '#{page_title}' not published in section"}
        published_revision -> {:ok, published_revision}
      end
    end
  end

  defp get_project_for_section(state, section) do
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn built_project ->
        built_project.project.id == section.base_project_id
      end)

    case project do
      nil -> {:error, "Source project for section not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp get_page_from_project(built_project, page_title) do
    case Map.get(built_project.rev_by_title, page_title) do
      nil -> {:error, "Page '#{page_title}' not found in project"}
      revision -> {:ok, revision}
    end
  end

  defp visit_page(user, section, page_revision) do
    datashop_session_id = "session_#{System.unique_integer([:positive])}"

    case PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id) do
      %PageContext{progress_state: :not_started, page: %{graded: true} = revision} = page_context ->
        start_graded_attempt(section, user, revision, datashop_session_id, page_context)

      %PageContext{} = page_context ->
        {:ok, attempt_result_from_page_context(page_context, section)}
    end
  end

  defp start_graded_attempt(section, user, page_revision, datashop_session_id, page_context) do
    publication_id = Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id)

    visit_context = %VisitContext{
      publication_id: publication_id,
      blacklisted_activity_ids: [],
      latest_resource_attempt: List.first(page_context.resource_attempts),
      page_revision: page_revision,
      section_slug: section.slug,
      user: user,
      audience_role: Oli.Delivery.Audience.audience_role(user, section.slug),
      datashop_session_id: datashop_session_id,
      activity_provider: &Oli.Delivery.ActivityProvider.provide/6,
      effective_settings: page_context.effective_settings
    }

    case Graded.start(visit_context) do
      {:ok, _attempt_state} ->
        case PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id) do
          %PageContext{} = page_context ->
            {:ok, attempt_result_from_page_context(page_context, section)}
        end

      {:error, {:active_attempt_present}} ->
        case PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id) do
          %PageContext{} = page_context ->
            {:ok, attempt_result_from_page_context(page_context, section)}
        end

      {:error, reason} ->
        {:error, "Graded.start failed: #{inspect(reason)}"}
    end
  end

  defp attempt_result_from_page_context(%PageContext{
         progress_state: :not_started,
         user: user,
         page: page_revision,
         resource_attempts: resource_attempts
       }, section) do
    resource_access =
      Core.get_resource_access(page_revision.resource_id, section.slug, user.id)

    {:not_started,
     %Oli.Delivery.Attempts.PageLifecycle.HistorySummary{
       resource_access: resource_access,
       resource_attempts: resource_attempts
     }}
  end

  defp attempt_result_from_page_context(%PageContext{
         progress_state: progress_state,
         resource_attempts: [resource_attempt | _],
         latest_attempts: latest_attempts,
         page: page_revision
       }, _section) do
    {:ok, attempt_state} =
      Oli.Delivery.Attempts.PageLifecycle.AttemptState.fetch_attempt_state(
        resource_attempt,
        page_revision
      )

    {progress_state, %{attempt_state | attempt_hierarchy: latest_attempts}}
  end
end
