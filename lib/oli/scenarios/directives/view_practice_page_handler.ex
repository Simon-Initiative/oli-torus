defmodule Oli.Scenarios.Directives.ViewPracticePageHandler do
  @moduledoc """
  Handles view_practice_page directives for simulating students viewing practice pages.

  This handler delegates to Oli.Delivery.Attempts.PageLifecycle.visit/6 to create
  or resume page attempts, storing the resulting AttemptState in the ExecutionState.

  The `student` field should reference the user's name (as defined in the user directive),
  not their email address.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ViewPracticePageDirective}
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Lti_1p3.Roles.ContextRoles

  @doc """
  Handles a view_practice_page directive by simulating a student viewing a practice page.

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%ViewPracticePageDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, user} <- get_user(state, directive.student),
         {:ok, section} <- get_section(state, directive.section),
         {:ok, _enrollment} <- ensure_enrollment(user, section),
         {:ok, page_revision} <- get_page_revision(state, directive.section, directive.page),
         {:ok, attempt_result} <- visit_page(user, section, page_revision) do
      # Store the attempt state using the user name, section name, and page title
      key = {directive.student, directive.section, directive.page}
      updated_attempts = Map.put(state.page_attempts, key, attempt_result)

      {:ok, %{state | page_attempts: updated_attempts}}
    else
      {:error, reason} ->
        {:error, "Failed to view practice page: #{reason}"}
    end
  end

  # Get user from state by name
  defp get_user(state, user_name) do
    case Map.get(state.users, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  # Get section from state
  defp get_section(state, section_name) do
    case Map.get(state.sections, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  # Ensure user is enrolled in section as learner
  defp ensure_enrollment(user, section) do
    # Check if already enrolled
    case Sections.get_enrollment(section.slug, user.id) do
      nil ->
        # Not enrolled, create enrollment
        learner_role = ContextRoles.get_role(:context_learner)
        case Sections.enroll([user.id], section.id, [learner_role]) do
          {:ok, _enrollments} -> {:ok, :enrolled}
          error -> {:error, "Failed to enroll: #{inspect(error)}"}
        end

      _enrollment ->
        # Already enrolled
        {:ok, :already_enrolled}
    end
  end

  # Get page revision from section
  defp get_page_revision(state, section_name, page_title) do
    with {:ok, section} <- get_section(state, section_name),
         {:ok, project} <- get_project_for_section(state, section),
         {:ok, page_rev} <- get_page_from_project(project, page_title) do
      # Get the published revision for this page in the section
      case DeliveryResolver.from_revision_slug(section.slug, page_rev.slug) do
        nil ->
          {:error, "Page '#{page_title}' not published in section"}
        published_revision ->
          {:ok, published_revision}
      end
    end
  end

  # Get the project that a section was created from
  defp get_project_for_section(state, section) do
    # Find the project that matches the section's base_project_id
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn built_project ->
        built_project.project.id == section.base_project_id
      end)

    case project do
      nil -> {:error, "Source project for section not found"}
      p -> {:ok, p}
    end
  end

  # Get page revision from built project
  defp get_page_from_project(built_project, page_title) do
    case Map.get(built_project.rev_by_title, page_title) do
      nil -> {:error, "Page '#{page_title}' not found in project"}
      revision -> {:ok, revision}
    end
  end

  # Visit the page using PageLifecycle
  defp visit_page(user, section, page_revision) do
    # First ensure ResourceAccess exists by tracking the access
    Core.track_access(
      page_revision.resource_id,
      section.id,
      user.id
    )

    # Generate a unique datashop session ID
    datashop_session_id = "session_#{System.unique_integer([:positive])}"

    # Get effective settings for this page/section/user combination
    effective_settings = Settings.get_combined_settings(
      page_revision,
      section.id,
      user.id
    )

    # Use the standard activity provider
    activity_provider = &Oli.Delivery.ActivityProvider.provide/6

    # Call PageLifecycle.visit/6
    case PageLifecycle.visit(
      page_revision,
      section.slug,
      datashop_session_id,
      user,
      effective_settings,
      activity_provider
    ) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "PageLifecycle.visit failed: #{inspect(reason)}"}
    end
  end
end
