defmodule Oli.Scenarios.Directives.DiscussionConfigHandler do
  @moduledoc """
  Configures course discussions on a scenario section.
  """

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Scenarios.DirectiveTypes.{DiscussionConfigDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(
        %DiscussionConfigDirective{
          section: section_name,
          enabled: enabled,
          auto_accept: auto_accept,
          anonymous_posting: anonymous_posting
        },
        %ExecutionState{} = state
      ) do
    with {:ok, section} <- fetch_section(state, section_name),
         {:ok, %{section: updated_section}} <-
           SectionsAudited.update_course_discussions(
             Context.for_actor(state.current_author, source: :scenario),
             section,
             config_changes(enabled, auto_accept, anonymous_posting)
           ) do
      {:ok, put_section_or_product(state, section_name, updated_section)}
    else
      {:error, reason} ->
        {:error, "Failed to configure discussions: #{inspect(reason)}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) || Engine.get_product(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  # Only the settings the directive names change.
  defp config_changes(enabled, auto_accept, anonymous_posting) do
    %{status: status(enabled), auto_accept: auto_accept, anonymous_posting: anonymous_posting}
    |> Map.reject(fn {_field, value} -> is_nil(value) end)
  end

  defp status(nil), do: nil
  defp status(true), do: :enabled
  defp status(false), do: :disabled

  defp put_section_or_product(state, name, updated_section) do
    if Engine.get_product(state, name) do
      Engine.put_product(state, name, updated_section)
    else
      Engine.put_section(state, name, updated_section)
    end
  end
end
