defmodule Oli.Scenarios.Directives.AttemptSupport do
  @moduledoc false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle.Graded
  alias Oli.Delivery.Attempts.PageLifecycle.VisitContext
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  def get_user(%ExecutionState{} = state, user_name) do
    case Map.get(state.users, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  def get_section(%ExecutionState{} = state, section_name) do
    case Map.get(state.sections, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  def ensure_enrollment(user, section) do
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

  def get_page_revision(%ExecutionState{} = state, section_name, page_title) do
    with {:ok, section} <- get_section(state, section_name),
         {:ok, project} <- get_project_for_section(state, section),
         {:ok, page_rev} <- get_page_from_project(project, page_title) do
      case DeliveryResolver.from_revision_slug(section.slug, page_rev.slug) do
        nil -> {:error, "Page '#{page_title}' not published in section"}
        published_revision -> {:ok, published_revision}
      end
    end
  end

  def visit_page(user, section, page_revision, opts \\ []) do
    datashop_session_id = Keyword.get_lazy(opts, :datashop_session_id, &datashop_session_id/0)
    password = Keyword.get(opts, :password)

    case PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id) do
      %PageContext{progress_state: :not_started, page: %{graded: true} = revision} = page_context ->
        start_graded_attempt(section, user, revision, datashop_session_id, page_context, password)

      %PageContext{} = page_context ->
        {:ok, attempt_result_from_page_context(page_context, section)}
    end
  end

  def put_attempt_result(
        %ExecutionState{} = state,
        student_name,
        section_name,
        page_title,
        result
      ) do
    key = {student_name, section_name, page_title}
    %{state | page_attempts: Map.put(state.page_attempts, key, result)}
  end

  def normalize_start_error({:ok, _attempt_result} = result), do: result
  def normalize_start_error({:error, :password_required}), do: {:error, :password_required}
  def normalize_start_error({:error, :incorrect_password}), do: {:error, :incorrect_password}
  def normalize_start_error({:error, :before_start_date}), do: {:error, :before_start_date}

  def normalize_start_error({:error, {:active_attempt_present}}),
    do: {:error, :active_attempt_present}

  def normalize_start_error({:error, {:no_more_attempts}}), do: {:error, :no_more_attempts}
  def normalize_start_error({:error, {:end_date_passed}}), do: {:error, :end_date_passed}
  def normalize_start_error({:error, reason}), do: {:error, reason}

  defp start_graded_attempt(
         section,
         user,
         page_revision,
         datashop_session_id,
         page_context,
         password
       ) do
    with :ok <-
           Oli.Delivery.Attempts.StartAttemptPolicy.validate(page_context.effective_settings,
             password: password
           ) do
      do_start_graded_attempt(section, user, page_revision, datashop_session_id, page_context)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_start_graded_attempt(section, user, page_revision, datashop_session_id, page_context) do
    publication_id =
      Publishing.get_publication_id_for_resource(section.slug, page_revision.resource_id)

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
        refresh_attempt_result(section, user, page_revision, datashop_session_id)

      {:error, {:active_attempt_present}} ->
        refresh_attempt_result(section, user, page_revision, datashop_session_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp refresh_attempt_result(section, user, page_revision, datashop_session_id) do
    case PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id) do
      %PageContext{} = page_context ->
        {:ok, attempt_result_from_page_context(page_context, section)}
    end
  end

  defp attempt_result_from_page_context(
         %PageContext{
           progress_state: :not_started,
           user: user,
           page: page_revision,
           resource_attempts: resource_attempts
         },
         section
       ) do
    resource_access =
      Core.get_resource_access(page_revision.resource_id, section.slug, user.id)

    {:not_started,
     %Oli.Delivery.Attempts.PageLifecycle.HistorySummary{
       resource_access: resource_access,
       resource_attempts: resource_attempts
     }}
  end

  defp attempt_result_from_page_context(
         %PageContext{
           progress_state: progress_state,
           resource_attempts: [resource_attempt | _],
           latest_attempts: latest_attempts,
           page: page_revision
         },
         _section
       ) do
    {:ok, attempt_state} =
      Oli.Delivery.Attempts.PageLifecycle.AttemptState.fetch_attempt_state(
        resource_attempt,
        page_revision
      )

    {progress_state, %{attempt_state | attempt_hierarchy: latest_attempts}}
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

  defp datashop_session_id, do: "session_#{System.unique_integer([:positive])}"
end
