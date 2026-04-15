defmodule Oli.Scenarios.Directives.Assert.PrologueAssertion do
  @moduledoc """
  Handles student prologue state assertions.
  """

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Page.PrologueState
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias OliWeb.Common.SessionContext

  def assert(%AssertDirective{prologue: prologue_spec}, state) when is_map(prologue_spec) do
    with {:ok, user} <- get_user(state, prologue_spec.student),
         {:ok, section} <- get_section(state, prologue_spec.section),
         {:ok, _enrollment} <- ensure_enrollment(user, section),
         {:ok, page_revision} <- get_page_revision(state, prologue_spec.section, prologue_spec.page) do
      prologue_state =
        PrologueState.create_for_visit(
          section,
          page_revision.slug,
          user,
          ctx: scenario_ctx(user, section)
        )

      verification =
        verify_prologue_state(
          prologue_spec.section,
          prologue_spec.page,
          prologue_spec,
          prologue_state
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def assert(%AssertDirective{prologue: nil}, state), do: {:ok, state, nil}

  defp verify_prologue_state(section_name, page_title, expected, actual) do
    try do
      assert_equal(:allow_attempt, expected.allow_attempt, actual.allow_attempt?)
      assert_equal(:show_blocking_gates, expected.show_blocking_gates, actual.show_blocking_gates?)
      assert_equal(:attempt_message, expected.attempt_message, actual.attempt_message)
      assert_equal(:attempts_taken, expected.attempts_taken, actual.attempts_taken)
      assert_equal(:max_attempts, expected.max_attempts, actual.max_attempts)
      assert_equal(:attempts_summary, expected.attempts_summary, actual.attempts_summary)
      assert_equal(:next_attempt_ordinal, expected.next_attempt_ordinal, actual.next_attempt_ordinal)
      assert_terms(expected.terms || %{}, actual.terms || [])

      %VerificationResult{
        to: section_name,
        passed: true,
        message: "Prologue state for '#{page_title}' matches expected"
      }
    rescue
      e ->
        %VerificationResult{
          to: section_name,
          passed: false,
          message: Exception.message(e)
        }
    end
  end

  defp assert_equal(_field, nil, _actual), do: :ok

  defp assert_equal(field, expected, actual) when expected != actual do
    raise "Prologue field '#{field}' mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp assert_equal(_field, _expected, _actual), do: :ok

  defp assert_terms(expected_terms, actual_terms) do
    actual_by_id = Map.new(actual_terms, fn term -> {term.id, term.text} end)

    Enum.each(expected_terms, fn {id, expected_text} ->
      actual_text = Map.get(actual_by_id, id)

      if actual_text != expected_text do
        raise "Prologue term '#{id}' mismatch: expected #{inspect(expected_text)}, got #{inspect(actual_text)}"
      end
    end)
  end

  defp get_user(state, user_name) do
    case Map.get(state.users, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  defp get_section(state, section_name) do
    case Engine.get_section(state, section_name) do
      nil ->
        case Engine.get_product(state, section_name) do
          nil -> {:error, "Section '#{section_name}' not found"}
          section -> {:ok, section}
        end

      section ->
        {:ok, section}
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

  defp scenario_ctx(user, section) do
    %SessionContext{
      SessionContext.init()
      | user: user,
        section: section,
        browser_timezone: "Etc/UTC",
        local_tz: "Etc/UTC"
    }
  end
end
